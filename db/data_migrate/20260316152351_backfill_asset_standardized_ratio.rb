class BackfillAssetStandardizedRatio < ActiveRecord::Migration[8.1]
  def up
    Asset.where(standardized_ratio: nil).where.not(width: nil, height: nil).find_each do |asset|
      ratio = Asset.snap_to_standard_ratio(asset.width, asset.height)
      asset.update_columns(standardized_ratio: ratio) if ratio
    end
  end

  def down; end
end
