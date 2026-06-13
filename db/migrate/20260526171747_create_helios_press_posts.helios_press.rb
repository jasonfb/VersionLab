# This migration comes from helios_press (originally 20250510000001)
class CreateHeliosPressPosts < ActiveRecord::Migration[8.0]
  def change
    primary_key_type, foreign_key_type = primary_and_foreign_key_types

    create_table :helios_press_posts, id: primary_key_type do |t|
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

  private

  def primary_and_foreign_key_types
    config = Rails.configuration.generators
    setting = config.options[config.orm][:primary_key_type]
    primary_key_type = setting || :primary_key
    foreign_key_type = setting || :bigint
    [ primary_key_type, foreign_key_type ]
  end
end
