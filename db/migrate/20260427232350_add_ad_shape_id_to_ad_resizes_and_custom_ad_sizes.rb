class AddAdShapeIdToAdResizesAndCustomAdSizes < ActiveRecord::Migration[8.1]
  def change
    add_column :ad_resizes, :ad_shape_id, :uuid
    add_foreign_key :ad_resizes, :ad_shapes
    add_index :ad_resizes, :ad_shape_id

    add_column :custom_ad_sizes, :ad_shape_id, :uuid
    add_foreign_key :custom_ad_sizes, :ad_shapes
    add_index :custom_ad_sizes, :ad_shape_id
  end
end
