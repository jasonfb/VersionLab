# This migration comes from helios_press (originally 20250510000003)
class CreateHeliosPressBlockImages < ActiveRecord::Migration[8.0]
  def change
    create_table :helios_press_block_images do |t|
      t.references :block, null: false, foreign_key: { to_table: :helios_press_blocks }
      t.integer :position, null: false
      t.text :caption

      t.timestamps
    end

    add_index :helios_press_block_images, [:block_id, :position]
  end
end
