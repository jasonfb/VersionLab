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
      resized_layers: resize.resized_layers,
      layer_overrides: resize.layer_overrides,
      preview_image_url: resize.preview_image.attached? ?
        Rails.application.routes.url_helpers.rails_blob_url(resize.preview_image, only_path: true) : nil,
      resized_svg_url: resize.resized_svg.attached? ?
        Rails.application.routes.url_helpers.rails_blob_url(resize.resized_svg, only_path: true) : nil
    }
  end
end
