# This migration comes from helios_press (originally 20250510000002)
class CreateHeliosPressBlocks < ActiveRecord::Migration[8.0]
  def change
    create_table :helios_press_blocks do |t|
      t.references :post, null: false, foreign_key: { to_table: :helios_press_posts }
      t.string :block_type, null: false
      t.integer :position, null: false
      t.integer :columns, default: 3

      t.timestamps
    end

    add_index :helios_press_blocks, [:post_id, :position]
  end
end
