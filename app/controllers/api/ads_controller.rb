class Api::AdsController < Api::BaseController
  before_action :set_client
  before_action :set_ad, only: [ :show, :update, :destroy, :run, :reject, :resize, :resizes, :results, :download_version, :classifications, :confirm_classifications ]

  def index
    ads = @client.ads.includes(:audiences, :campaign, :ai_service, :ai_model)
                     .order(updated_at: :desc)
    render json: ads.map { |a| ad_json(a) }
  end

  def show
    render json: ad_json(@ad)
  end

  def create
    ad = @client.ads.build(name: params[:name].presence || "Untitled Ad")

    if params[:file].present?
      ad.file.attach(params[:file])
    end

    if ad.save
      AdParseService.new(ad).call if ad.file.attached?
      ad.reload
      render json: ad_json(ad), status: :created
    else
      render json: { errors: ad.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    ad_params = params[:ad] || {}

    @ad.name = ad_params[:name] if ad_params.key?(:name)
    @ad.background_type = ad_params[:background_type] if ad_params.key?(:background_type)
    @ad.background_color = ad_params[:background_color] if ad_params.key?(:background_color)
    @ad.background_asset_id = ad_params[:background_asset_id] if ad_params.key?(:background_asset_id)
    @ad.overlay_enabled = ad_params[:overlay_enabled] if ad_params.key?(:overlay_enabled)
    @ad.overlay_type = ad_params[:overlay_type] if ad_params.key?(:overlay_type)
    @ad.overlay_color = ad_params[:overlay_color] if ad_params.key?(:overlay_color)
    @ad.overlay_opacity = ad_params[:overlay_opacity] if ad_params.key?(:overlay_opacity)
    @ad.play_button_enabled = ad_params[:play_button_enabled] if ad_params.key?(:play_button_enabled)
    @ad.play_button_style = ad_params[:play_button_style] if ad_params.key?(:play_button_style)
    @ad.play_button_color = ad_params[:play_button_color] if ad_params.key?(:play_button_color)
    @ad.versioning_mode = ad_params[:versioning_mode] if ad_params.key?(:versioning_mode)
    @ad.nlp_prompt = ad_params[:nlp_prompt] if ad_params.key?(:nlp_prompt)
    @ad.keep_background = ad_params[:keep_background] if ad_params.key?(:keep_background)
    @ad.output_format = ad_params[:output_format] if ad_params.key?(:output_format)
    @ad.ai_service_id = ad_params[:ai_service_id] if ad_params.key?(:ai_service_id)
    @ad.ai_model_id = ad_params[:ai_model_id] if ad_params.key?(:ai_model_id)
    @ad.layer_overrides = ad_params[:layer_overrides] if ad_params.key?(:layer_overrides)

    if ad_params.key?(:campaign_id)
      @ad.campaign = ad_params[:campaign_id].present? ? @client.campaigns.find_by(id: ad_params[:campaign_id]) : nil
    end

    if ad_params.key?(:audience_ids)
      audiences = @client.audiences.where(id: ad_params[:audience_ids])
      @ad.audiences = audiences
    end

    if @ad.save
      render json: ad_json(@ad)
    else
      render json: { errors: @ad.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @ad.destroy
    head :no_content
  end

  # GET /api/clients/:client_id/ads/:id/classifications
  def classifications
    render json: {
      classified_layers: @ad.classified_layers,
      classifications_confirmed: @ad.classifications_confirmed
    }
  end

  # POST /api/clients/:client_id/ads/:id/confirm_classifications
  def confirm_classifications
    layers = params[:classified_layers]
    unless layers.is_a?(Array) && layers.any?
      return render json: { error: "classified_layers is required" }, status: :unprocessable_entity
    end

    @ad.update!(
      classified_layers: layers.map { |l| l.permit!.to_h },
      classifications_confirmed: true
    )

    render json: {
      classified_layers: @ad.classified_layers,
      classifications_confirmed: @ad.classifications_confirmed
    }
  end

  # POST /api/clients/:client_id/ads/:id/resize
  def resize
    unless @ad.setup? || @ad.resizing?
      return render json: { error: "Ad must be in setup or resizing state to resize" }, status: :unprocessable_entity
    end

    unless @ad.classifications_confirmed?
      return render json: { error: "Element classifications must be confirmed before resizing" }, status: :unprocessable_entity
    end

    platforms = params[:platforms]
    unless platforms.is_a?(Array) && platforms.any?
      return render json: { error: "At least one platform must be selected" }, status: :unprocessable_entity
    end

    # Clear any existing versions if going back from Step 2
    @ad.ad_versions.destroy_all if @ad.ad_versions.any?

    resizes = AdResizeService.new(@ad, platforms: platforms).call
    @ad.update!(state: :resizing)

    render json: {
      ad_id: @ad.id,
      state: @ad.state,
      resizes: resizes.compact.map { |r| resize_json(r) }
    }
  rescue AdResizeService::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /api/clients/:client_id/ads/:id/resizes
  def resizes
    render json: @ad.ad_resizes.order(:width, :height).map { |r| resize_json(r) }
  end

  def run
    unless @ad.setup? || @ad.resizing?
      return render json: { error: "Ad must be in setup or resizing state to run" }, status: :unprocessable_entity
    end

    unless @ad.ai_service_id.present? && @ad.ai_model_id.present?
      return render json: { error: "Ad must have an AI service and model selected" }, status: :unprocessable_entity
    end

    unless @ad.audiences.any?
      return render json: { error: "Ad must have at least one audience selected" }, status: :unprocessable_entity
    end

    has_text_layers = if @ad.ad_resizes.where(state: :resized).any?
      @ad.ad_resizes.where(state: :resized).any? { |r| r.resized_layers.any? { |l| l["type"] == "text" } }
    else
      @ad.parsed_layers.any? { |l| l["type"] == "text" }
    end

    unless has_text_layers
      return render json: { error: "No editable text layers found in this ad" }, status: :unprocessable_entity
    end

    unless AiKey.exists?(ai_service_id: @ad.ai_service_id)
      return render json: { error: "No API key configured for the selected AI service" }, status: :unprocessable_entity
    end

    @ad.update!(state: :pending)
    AdJob.perform_later(@ad.id)
    render json: ad_json(@ad)
  end

  def reject
    unless @ad.merged? || @ad.regenerating?
      return render json: { error: "Cannot reject a version while generation is not yet complete" }, status: :unprocessable_entity
    end

    rejection_comment = params[:rejection_comment].to_s.strip
    if rejection_comment.blank?
      return render json: { error: "Rejection comment is required" }, status: :unprocessable_entity
    end

    if params[:version_id].present?
      reject_single_version(rejection_comment)
    elsif params[:audience_id].present?
      reject_audience(rejection_comment)
    else
      render json: { error: "Must specify version_id or audience_id" }, status: :unprocessable_entity
    end
  end

  def results
    audiences = @ad.audiences.to_a
    resizes = @ad.ad_resizes.order(:width, :height).to_a
    versions = @ad.ad_versions.includes(:ai_service, :ai_model, :audience, :ad_resize)
                   .order(:version_number)

    audiences_data = audiences.map do |a|
      audience_versions = versions.select { |v| v.audience_id == a.id }
      {
        id: a.id,
        name: a.name,
        versions: audience_versions.map { |v| version_json(v) }
      }
    end

    render json: {
      ad_id: @ad.id,
      state: @ad.state,
      ad_name: @ad.name,
      aspect_ratio: @ad.aspect_ratio,
      parsed_layers: @ad.parsed_layers,
      resizes: resizes.map { |r| resize_json(r) },
      audiences: audiences_data
    }
  end

  def download_version
    version = @ad.ad_versions.find(params[:version_id])
    unless version.rendered_image.attached?
      return render json: { error: "Rendered image not available" }, status: :not_found
    end

    redirect_to Rails.application.routes.url_helpers.rails_blob_url(
      version.rendered_image, only_path: true, disposition: "attachment"
    ), allow_other_host: true
  end

  private

  def reject_single_version(rejection_comment)
    version = @ad.ad_versions.find(params[:version_id])
    unless version.active?
      return render json: { error: "Version is not active" }, status: :unprocessable_entity
    end

    new_version = nil
    AdVersion.transaction do
      version.update!(state: :rejected, rejection_comment: rejection_comment)
      new_version = @ad.ad_versions.create!(
        audience: version.audience,
        ad_resize: version.ad_resize,
        version_number: version.version_number + 1,
        state: :generating,
        ai_service_id: @ad.ai_service_id,
        ai_model_id: @ad.ai_model_id
      )
      @ad.update!(state: :regenerating)
    end

    AdJob.perform_later(
      @ad.id,
      audience_id: version.audience_id.to_s,
      rejection_comment: rejection_comment,
      ad_resize_id: version.ad_resize_id
    )

    render json: {
      ad_id: @ad.id,
      state: @ad.state,
      new_version_id: new_version.id,
      new_version_number: new_version.version_number
    }
  end

  def reject_audience(rejection_comment)
    audience = @ad.audiences.find(params[:audience_id])
    active_versions = @ad.ad_versions.where(audience: audience, state: :active)

    unless active_versions.any?
      return render json: { error: "No active versions for this audience" }, status: :unprocessable_entity
    end

    AdVersion.transaction do
      active_versions.each do |version|
        version.update!(state: :rejected, rejection_comment: rejection_comment)
        @ad.ad_versions.create!(
          audience: audience,
          ad_resize: version.ad_resize,
          version_number: version.version_number + 1,
          state: :generating,
          ai_service_id: @ad.ai_service_id,
          ai_model_id: @ad.ai_model_id
        )
      end
      @ad.update!(state: :regenerating)
    end

    AdJob.perform_later(@ad.id, audience_id: audience.id.to_s, rejection_comment: rejection_comment)

    render json: {
      ad_id: @ad.id,
      state: @ad.state,
      audience_id: audience.id
    }
  end

  def set_client
    @client = @current_account.clients.find(params[:client_id])
  end

  def set_ad
    @ad = @client.ads.find(params[:id])
  end

  def version_json(version)
    {
      id: version.id,
      version_number: version.version_number,
      state: version.state,
      rejection_comment: version.rejection_comment,
      ad_resize_id: version.ad_resize_id,
      resize_dimensions: version.ad_resize ? version.ad_resize.dimensions : nil,
      resize_label: version.ad_resize&.label,
      ai_service_name: version.ai_service.name,
      ai_model_name: version.ai_model.name,
      generated_layers: version.generated_layers,
      rendered_image_url: version.rendered_image.attached? ?
        Rails.application.routes.url_helpers.rails_blob_url(version.rendered_image, only_path: true) : nil
    }
  end

  def resize_json(resize)
    {
      id: resize.id,
      platform_labels: resize.platform_labels,
      label: resize.label,
      width: resize.width,
      height: resize.height,
      aspect_ratio: resize.aspect_ratio,
      dimensions: resize.dimensions,
      state: resize.state,
      resized_layers: resize.resized_layers,
      layer_overrides: resize.layer_overrides,
      preview_image_url: resize.preview_image.attached? ?
        Rails.application.routes.url_helpers.rails_blob_url(resize.preview_image, only_path: true) : nil,
      resized_svg_url: resize.resized_svg.attached? ?
        Rails.application.routes.url_helpers.rails_blob_url(resize.resized_svg, only_path: true) : nil
    }
  end

  def ad_json(ad)
    {
      id: ad.id,
      client_id: ad.client_id,
      name: ad.name,
      state: ad.state,
      background_type: ad.background_type,
      background_color: ad.background_color,
      background_asset_id: ad.background_asset_id,
      overlay_enabled: ad.overlay_enabled,
      overlay_type: ad.overlay_type,
      overlay_color: ad.overlay_color,
      overlay_opacity: ad.overlay_opacity,
      play_button_enabled: ad.play_button_enabled,
      play_button_style: ad.play_button_style,
      play_button_color: ad.play_button_color,
      versioning_mode: ad.versioning_mode,
      campaign_id: ad.campaign_id,
      campaign_name: ad.campaign&.name,
      nlp_prompt: ad.nlp_prompt,
      keep_background: ad.keep_background,
      output_format: ad.output_format,
      ai_service_id: ad.ai_service_id,
      ai_model_id: ad.ai_model_id,
      width: ad.width,
      height: ad.height,
      aspect_ratio: ad.aspect_ratio,
      parsed_layers: ad.parsed_layers,
      classified_layers: ad.classified_layers,
      classifications_confirmed: ad.classifications_confirmed,
      file_warnings: ad.file_warnings,
      audience_ids: ad.audiences.map(&:id),
      audience_names: ad.audiences.map(&:name),
      layer_overrides: ad.layer_overrides,
      svg_url: ad.svg_url,
      file_url: ad.file_url,
      file_content_type: ad.file_content_type,
      has_resizes: ad.ad_resizes.any?,
      resize_count: ad.ad_resizes.count,
      updated_at: ad.updated_at,
      fonts: ad.ad_fonts.select { |f| f.font_file.attached? }.map { |f|
        {
          name: f.font_name,
          postscript_name: f.postscript_name,
          url: rails_blob_url(f.font_file, only_path: true),
        }
      }
    }
  end
end
