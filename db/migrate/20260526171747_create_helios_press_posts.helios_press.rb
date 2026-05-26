# This migration comes from helios_press (originally 20250510000001)
class CreateHeliosPressPosts < ActiveRecord::Migration[8.0]
  def change
    create_table :helios_press_posts do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :keywords
      t.boolean :published, default: false, null: false
      t.string :external_id

      t.timestamps
    end

    add_index :helios_press_posts, :slug, unique: true
    add_index :helios_press_posts, :external_id, unique: true
    add_index :helios_press_posts, :published
  end
end
