class Api::AssetsController < Api::BaseController
  def index
    assets = @current_account.assets.order(created_at: :desc).map do |asset|
      asset_json(asset)
    end

    render json: assets
  end

  def create
    asset = @current_account.assets.new(name: params[:file].original_filename)
    asset.file.attach(params[:file])

    if asset.file.attached? && asset.file.blob.image?
      asset.file.blob.analyze
      metadata = asset.file.blob.metadata
      asset.width = metadata[:width]
      asset.height = metadata[:height]
    end

    if asset.save
      render json: asset_json(asset), status: :created
    else
      render json: { errors: asset.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    asset = @current_account.assets.find(params[:id])
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
      url: asset.file.attached? ? rails_blob_url(asset.file, disposition: "inline") : nil,
      created_at: asset.created_at
    }
  end
end
