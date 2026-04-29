class Api::AssetsController < Api::BaseController
  def index
    assets = @current_client.assets.where(assetable_id: nil).order(created_at: :desc).map do |asset|
      asset_json(asset)
    end

    render json: assets
  end

  def create
    asset = @current_client.assets.new(name: params[:file].original_filename)
    asset.file.attach(params[:file])

    if asset.save
      if asset.file.blob.image?
        asset.file.blob.analyze
        metadata = asset.file.blob.metadata
        w, h = metadata[:width], metadata[:height]
        asset.update(
          width: w,
          height: h,
          standardized_ratio: Asset.snap_to_standard_ratio(w, h)
        )
      end

      render json: asset_json(asset), status: :created
    else
      render json: { errors: asset.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    asset = @current_client.assets.find(params[:id])
    asset.destroy!
    head :no_content
  end

  private

  def asset_json(asset)
    {
      id: asset.id,
      name: asset.name,
      width: asset.width,
      height: asset.height,
      standardized_ratio: asset.standardized_ratio,
      url: asset.file.attached? ? rails_blob_url(asset.file, disposition: "inline") : nil,
      created_at: asset.created_at
    }
  end
end
