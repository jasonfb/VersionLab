class CreateAdPlatforms < ActiveRecord::Migration[8.1]
  def change
    create_table :ad_platforms, id: :uuid do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :ad_platforms, :name, unique: true
    add_index :ad_platforms, :position
  end
end
