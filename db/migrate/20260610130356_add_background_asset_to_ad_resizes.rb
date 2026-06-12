class AddBackgroundAssetToAdResizes < ActiveRecord::Migration[8.1]
  def change
    add_column :ad_resizes, :background_asset_id, :uuid
  end
end
