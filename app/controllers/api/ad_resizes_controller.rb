class Api::AdResizesController < Api::BaseController
  before_action :set_client
  before_action :set_ad
  before_action :set_resize

  def update
    if params[:layer_overrides].present?
      @resize.update!(layer_overrides: params[:layer_overrides])
    end

    render json: resize_json(@resize)
  end

  # Destroy & rebuild a single resize so it picks up the latest layer
  # classifications without regenerating every other size.
  def rebuild
    new_resize = AdResizeService.rebuild(@resize)
    render json: resize_json(new_resize)
  rescue AdResizeService::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # Switch the layout variant (left/center/right) and regenerate the resize.
  def switch_variant
    variant = params[:layout_variant]
    unless AdResize::LAYOUT_VARIANTS.include?(variant)
      return render json: { error: "Invalid variant. Must be one of: #{AdResize::LAYOUT_VARIANTS.join(', ')}" },
                    status: :unprocessable_entity
    end

    new_resize = AdResizeService.rebuild(@resize, layout_variant: variant)
    render json: resize_json(new_resize)
  rescue AdResizeService::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_client
    @client = @current_account.clients.find(params[:client_id])
  end

  def set_ad
    @ad = @client.ads.find(params[:ad_id])
  end

  def set_resize
    @resize = @ad.ad_resizes.find(params[:id])
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
      layout_variant: resize.layout_variant,
      resized_layers: resize.resized_layers,
      layer_overrides: resize.layer_overrides,
      preview_image_url: resize.preview_image.attached? ?
        Rails.application.routes.url_helpers.rails_blob_url(resize.preview_image, only_path: true) : nil,
      resized_svg_url: resize.resized_svg.attached? ?
        Rails.application.routes.url_helpers.rails_blob_url(resize.resized_svg, only_path: true) : nil
    }
  end
end
