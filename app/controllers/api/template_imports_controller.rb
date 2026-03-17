class Api::TemplateImportsController < Api::BaseController
  before_action :set_client

  def create
    return render_error("Name is required") if params[:name].blank?
    return render_error("Import type must be bundled or external") unless %w[bundled external].include?(params[:import_type])
    return render_error("File is required") if params[:file].blank?

    file = params[:file]

    if params[:import_type] == "bundled"
      valid_zip = file.content_type.in?(%w[application/zip application/x-zip-compressed]) ||
                  file.original_filename.to_s.end_with?(".zip")
      return render_error("Bundled import requires a ZIP file (.zip)") unless valid_zip
    else
      valid_html = file.content_type.in?(%w[text/html application/xhtml+xml]) ||
                   file.original_filename.to_s.end_with?(".html", ".htm")
      return render_error("External import requires an HTML file (.html)") unless valid_html
    end

    # Upload to storage before opening the transaction so the blob is
    # available the instant Solid Queue picks up the job.
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file,
      filename: file.original_filename,
      content_type: file.content_type
    )

    import = nil
    ActiveRecord::Base.transaction do
      template = @client.email_templates.create!(name: params[:name])
      import = TemplateImport.create!(
        email_template: template,
        import_type: params[:import_type]
      )
      import.source_file.attach(blob)
    end

    TemplateImportJob.perform_later(import.id)

    render json: {
      id: import.id,
      email_template_id: import.email_template_id,
      state: import.state
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def set_client
    @client = @current_account.clients.find(params[:client_id])
  end

  def render_error(message)
    render json: { errors: [message] }, status: :unprocessable_entity
  end
end
