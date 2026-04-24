class Api::EmailsController < Api::BaseController
  before_action :set_client
  before_action :set_email, only: [:show, :update, :destroy, :run, :results, :preview, :reject, :export, :summarize]

  def index
    emails = Email.joins(:email_template)
                  .where(email_templates: { client_id: @client.id })
                  .includes(:email_template, :audiences, :campaign)
                  .order(updated_at: :desc)

    render json: emails.map { |e| email_json(e) }
  end

  def show
    render json: email_json(@email)
  end

  def create
    template = @client.email_templates.find(params[:email][:email_template_id])
    email = template.emails.build(state: "setup")
    email.client = @client
    email.ai_service_id = params[:email][:ai_service_id]
    email.ai_model_id = params[:email][:ai_model_id]
    email.context = params[:email][:context].presence

    if params[:email][:campaign_id].present?
      email.campaign = @client.campaigns.find_by(id: params[:email][:campaign_id])
    end

    if params[:email][:audience_ids].present?
      audiences = @client.audiences.where(id: params[:email][:audience_ids])
      email.audiences = audiences
    end

    if email.save
      render json: email_json(email), status: :created
    else
      render json: { errors: email.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @email.ai_service_id = params[:email][:ai_service_id] if params[:email].key?(:ai_service_id)
    @email.ai_model_id = params[:email][:ai_model_id] if params[:email].key?(:ai_model_id)
    @email.context = params[:email][:context].presence if params[:email].key?(:context)

    if params[:email].key?(:campaign_id)
      @email.campaign = params[:email][:campaign_id].present? ? @client.campaigns.find_by(id: params[:email][:campaign_id]) : nil
    end

    if params[:email][:audience_ids]
      audiences = @client.audiences.where(id: params[:email][:audience_ids])
      @email.audiences = audiences
    end

    if @email.save
      render json: email_json(@email)
    else
      render json: { errors: @email.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @email.destroy
    head :no_content
  end

  def run
    unless @email.setup?
      return render json: { error: "Email must be in setup state to run" }, status: :unprocessable_entity
    end

    # Apply account AI defaults when customer doesn't choose
    unless @current_account.customer_chooses_ai?
      @email.update!(ai_service_id: @current_account.ai_service_id, ai_model_id: @current_account.ai_model_id)
    end

    unless @email.ai_service_id.present? && @email.ai_model_id.present?
      return render json: { error: "Email must have an AI service and model selected" }, status: :unprocessable_entity
    end

    unless @email.audiences.any?
      return render json: { error: "Email must have at least one audience" }, status: :unprocessable_entity
    end

    unless AiKey.exists?(ai_service_id: @email.ai_service_id)
      return render json: { error: "No API key configured for the selected AI service" }, status: :unprocessable_entity
    end

    @email.update!(state: :pending)
    EmailJob.perform_later(@email.id)
    render json: email_json(@email)
  end

  def reject
    unless @email.merged? || @email.regenerating?
      return render json: { error: "Cannot reject a version while merge is not yet complete" }, status: :unprocessable_entity
    end

    audience = @email.audiences.find(params[:audience_id])
    active_version = @email.email_versions
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
    EmailVersion.transaction do
      active_version.update!(state: :rejected, rejection_comment: rejection_comment)
      new_version = @email.email_versions.create!(
        audience: audience,
        version_number: active_version.version_number + 1,
        state: :generating,
        ai_service_id: @email.ai_service_id,
        ai_model_id: @email.ai_model_id
      )
      @email.update!(state: :regenerating)
    end

    EmailJob.perform_later(@email.id, audience_id: audience.id.to_s, rejection_comment: rejection_comment)

    render json: {
      email_id: @email.id,
      state: @email.state,
      audience_id: audience.id,
      new_version_number: new_version.version_number
    }
  end

  def results
    audiences = @email.audiences.to_a
    variables = @email.email_template.template_variables
                      .where(variable_type: "text")
                      .order(:position)

    versions = @email.email_versions
                     .includes(:ai_service, :ai_model, :email_version_variables)
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
      email_id: @email.id,
      state: @email.state,
      email_template_name: @email.email_template.name,
      audiences: audiences_data,
      variables: variables.map { |v| { id: v.id, name: v.name, default_value: v.default_value } }
    }
  end

  def export
    require "zip"

    zip_data = Zip::OutputStream.write_buffer do |zip|
      @email.audiences.each do |audience|
        version = @email.email_versions
                        .where(audience: audience, state: :active)
                        .order(version_number: :desc)
                        .first
        next unless version

        overrides = version.email_version_variables.each_with_object({}) do |v, h|
          h[v.template_variable_id] = v.value
        end

        html = @email.email_template.render_html(overrides)
        filename = "#{audience.name.parameterize}.html"
        zip.put_next_entry(filename)
        zip.write(html)
      end
    end

    zip_name = "#{@email.email_template.name.parameterize}-email-export.zip"
    send_data zip_data.string, filename: zip_name, type: "application/zip", disposition: "attachment"
  end

  def summarize
    EmailSummaryJob.perform_later(@email.id)
    @email.update!(ai_summary_state: :generating)
    render json: { ai_summary_state: @email.ai_summary_state }
  end

  def preview
    audience = @email.audiences.find(params[:audience_id])
    version = @email.email_versions
                    .where(audience: audience, state: :active)
                    .order(version_number: :desc)
                    .first

    unless version
      return render html: "<p style='font-family:sans-serif;padding:2rem;color:#666'>No active version available for this audience yet.</p>".html_safe
    end

    overrides = version.email_version_variables.each_with_object({}) do |v, h|
      h[v.template_variable_id] = v.value
    end

    render html: @email.email_template.render_html(overrides).html_safe
  end

  private

  def set_client
    @client = @current_account.clients.find(params[:client_id])
  end

  def set_email
    @email = Email.joins(:email_template)
                  .where(email_templates: { client_id: @client.id })
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
      values: version.email_version_variables.each_with_object({}) { |v, h| h[v.template_variable_id] = v.value }
    }
  end

  def email_json(email)
    {
      id: email.id,
      client_id: email.client_id,
      email_template_id: email.email_template_id,
      email_template_name: email.email_template.name,
      campaign_id: email.campaign_id,
      campaign_name: email.campaign&.name,
      context: email.context,
      state: email.state,
      audience_ids: email.audiences.map(&:id),
      audience_names: email.audiences.map(&:name),
      ai_service_id: email.ai_service_id,
      ai_model_id: email.ai_model_id,
      ai_summary_state: email.ai_summary_state,
      ai_summary: email.ai_summary,
      ai_summary_generated_at: email.ai_summary_generated_at,
      updated_at: email.updated_at
    }
  end
end
