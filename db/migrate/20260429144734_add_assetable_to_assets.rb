class AddAssetableToAssets < ActiveRecord::Migration[8.1]
  def change
    change_table :assets, bulk: true do |t|
      t.string :assetable_type
      t.uuid :assetable_id
      t.text :content_text
      t.string :display_name
    end

    add_index :assets, [ :assetable_type, :assetable_id ]
  end
end
