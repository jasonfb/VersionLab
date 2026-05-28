# This migration comes from helios_press (originally 20250510000002)
class CreateHeliosPressBlocks < ActiveRecord::Migration[8.0]
  def change
    primary_key_type, foreign_key_type = primary_and_foreign_key_types

    create_table :helios_press_blocks, id: primary_key_type do |t|
      t.references :post, null: false, foreign_key: { to_table: :helios_press_posts }, type: foreign_key_type
      t.string :block_type, null: false
      t.integer :position, null: false
      t.integer :columns, default: 3

      t.timestamps
    end

    add_index :helios_press_blocks, [:post_id, :position]
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
