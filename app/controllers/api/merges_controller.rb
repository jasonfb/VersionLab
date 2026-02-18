class Api::MergesController < Api::BaseController
  before_action :set_project
  before_action :set_merge, only: [:update, :destroy, :run, :results, :preview, :reject, :export]

  def index
    merges = Merge.joins(:email_template)
                  .where(email_templates: { project_id: @project.id })
                  .includes(:email_template, :audiences)
                  .order(updated_at: :desc)

    render json: merges.map { |m| merge_json(m) }
  end

  def create
    template = @project.email_templates.find(params[:merge][:email_template_id])
    merge = template.merges.build(state: "setup")
    merge.ai_service_id = params[:merge][:ai_service_id]
    merge.ai_model_id = params[:merge][:ai_model_id]

    if params[:merge][:audience_ids].present?
      audiences = @project.audiences.where(id: params[:merge][:audience_ids])
      merge.audiences = audiences
    end

    if merge.save
      render json: merge_json(merge), status: :created
    else
      render json: { errors: merge.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @merge.ai_service_id = params[:merge][:ai_service_id] if params[:merge].key?(:ai_service_id)
    @merge.ai_model_id = params[:merge][:ai_model_id] if params[:merge].key?(:ai_model_id)

    if params[:merge][:audience_ids]
      audiences = @project.audiences.where(id: params[:merge][:audience_ids])
      @merge.audiences = audiences
    end

    if @merge.save
      render json: merge_json(@merge)
    else
      render json: { errors: @merge.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @merge.destroy
    head :no_content
  end

  def run
    unless @merge.setup?
      return render json: { error: "Merge must be in setup state to run" }, status: :unprocessable_entity
    end

    unless @merge.ai_service_id.present? && @merge.ai_model_id.present?
      return render json: { error: "Merge must have an AI service and model selected" }, status: :unprocessable_entity
    end

    unless @merge.audiences.any?
      return render json: { error: "Merge must have at least one audience" }, status: :unprocessable_entity
    end

    ai_key = @current_account.ai_keys.find_by(ai_service_id: @merge.ai_service_id)
    unless ai_key
      return render json: { error: "No API key configured for the selected AI service" }, status: :unprocessable_entity
    end

    @merge.update!(state: :pending)
    MergeJob.perform_later(@merge.id)
    render json: merge_json(@merge)
  end

  def reject
    unless @merge.merged? || @merge.regenerating?
      return render json: { error: "Cannot reject a version while merge is not yet complete" }, status: :unprocessable_entity
    end

    audience = @merge.audiences.find(params[:audience_id])
    active_version = @merge.merge_versions
                            .where(audience: audience, state: :active)
                            .order(version_number: :desc)
                            .first

    unless active_version
      return render json: { error: "No active version found for this audience" }, status: :unprocessable_entity
    end

    rejection_comment = params[:rejection_comment].to_s.strip
    if rejection_comment.blank?
      return render json: { error: "Rejection comment is required" }, status: :unprocessable_entity
    end

    new_version = nil
    MergeVersion.transaction do
      active_version.update!(state: :rejected, rejection_comment: rejection_comment)
      new_version = @merge.merge_versions.create!(
        audience: audience,
        version_number: active_version.version_number + 1,
        state: :generating,
        ai_service_id: @merge.ai_service_id,
        ai_model_id: @merge.ai_model_id
      )
      @merge.update!(state: :regenerating)
    end

    MergeJob.perform_later(@merge.id, audience_id: audience.id.to_s, rejection_comment: rejection_comment)

    render json: {
      merge_id: @merge.id,
      state: @merge.state,
      audience_id: audience.id,
      new_version_number: new_version.version_number
    }
  end

  def results
    audiences = @merge.audiences.to_a
    variables = @merge.email_template.template_variables
                      .where(variable_type: "text")
                      .order(:position)

    versions = @merge.merge_versions
                     .includes(:ai_service, :ai_model, :merge_version_variables)
                     .order(:version_number)

    versions_by_audience = versions.group_by(&:audience_id)

    audiences_data = audiences.map do |a|
      audience_versions = versions_by_audience[a.id] || []
      {
        id: a.id,
        name: a.name,
        versions: audience_versions.map { |v| version_json(v) }
      }
    end

    render json: {
      merge_id: @merge.id,
      state: @merge.state,
      email_template_name: @merge.email_template.name,
      audiences: audiences_data,
      variables: variables.map { |v| { id: v.id, name: v.name, default_value: v.default_value } }
    }
  end

  def export
    require "zip"

    zip_data = Zip::OutputStream.write_buffer do |zip|
      @merge.audiences.each do |audience|
        version = @merge.merge_versions
                        .where(audience: audience, state: :active)
                        .order(version_number: :desc)
                        .first
        next unless version

        overrides = version.merge_version_variables.each_with_object({}) do |v, h|
          h[v.template_variable_id] = v.value
        end

        html = @merge.email_template.render_html(overrides)
        filename = "#{audience.name.parameterize}.html"
        zip.put_next_entry(filename)
        zip.write(html)
      end
    end

    zip_name = "#{@merge.email_template.name.parameterize}-merge-export.zip"
    send_data zip_data.string, filename: zip_name, type: "application/zip", disposition: "attachment"
  end

  def preview
    audience = @merge.audiences.find(params[:audience_id])
    version = @merge.merge_versions
                    .where(audience: audience, state: :active)
                    .order(version_number: :desc)
                    .first

    unless version
      return render html: "<p style='font-family:sans-serif;padding:2rem;color:#666'>No active version available for this audience yet.</p>".html_safe
    end

    overrides = version.merge_version_variables.each_with_object({}) do |v, h|
      h[v.template_variable_id] = v.value
    end

    render html: @merge.email_template.render_html(overrides).html_safe
  end

  private

  def set_project
    @project = @current_account.projects.find(params[:project_id])
  end

  def set_merge
    @merge = Merge.joins(:email_template)
                  .where(email_templates: { project_id: @project.id })
                  .find(params[:id])
  end

  def version_json(version)
    {
      id: version.id,
      version_number: version.version_number,
      state: version.state,
      rejection_comment: version.rejection_comment,
      ai_service_name: version.ai_service.name,
      ai_model_name: version.ai_model.name,
      values: version.merge_version_variables.each_with_object({}) { |v, h| h[v.template_variable_id] = v.value }
    }
  end

  def merge_json(merge)
    {
      id: merge.id,
      email_template_id: merge.email_template_id,
      email_template_name: merge.email_template.name,
      state: merge.state,
      audience_ids: merge.audiences.map(&:id),
      audience_names: merge.audiences.map(&:name),
      ai_service_id: merge.ai_service_id,
      ai_model_id: merge.ai_model_id,
      updated_at: merge.updated_at
    }
  end
end
