class CreateAdPlatformSizes < ActiveRecord::Migration[8.1]
  def change
    create_table :ad_platform_sizes, id: :uuid do |t|
      t.uuid :ad_platform_id, null: false
      t.string :name, null: false
      t.integer :width, null: false
      t.integer :height, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_foreign_key :ad_platform_sizes, :ad_platforms
    add_index :ad_platform_sizes, :ad_platform_id
    add_index :ad_platform_sizes, [:ad_platform_id, :name], unique: true
  end
end
