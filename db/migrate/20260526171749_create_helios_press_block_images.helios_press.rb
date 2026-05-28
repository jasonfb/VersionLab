# This migration comes from helios_press (originally 20250510000003)
class CreateHeliosPressBlockImages < ActiveRecord::Migration[8.0]
  def change
    primary_key_type, foreign_key_type = primary_and_foreign_key_types

    create_table :helios_press_block_images, id: primary_key_type do |t|
      t.references :block, null: false, foreign_key: { to_table: :helios_press_blocks }, type: foreign_key_type
      t.integer :position, null: false
      t.text :caption

      t.timestamps
    end

    add_index :helios_press_block_images, [:block_id, :position]
  end

  private

  def primary_and_foreign_key_types
    config = Rails.configuration.generators
    setting = config.options[config.orm][:primary_key_type]
    primary_key_type = setting || :primary_key
    foreign_key_type = setting || :bigint
    [primary_key_type, foreign_key_type]
  end
end
