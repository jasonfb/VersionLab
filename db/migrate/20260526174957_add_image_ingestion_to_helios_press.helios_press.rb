# This migration comes from helios_press (originally 20250526000001)
class AddImageIngestionToHeliosPress < ActiveRecord::Migration[8.0]
  def change
    add_column :helios_press_block_images, :reference_key, :string
    add_index :helios_press_block_images, [ :block_id, :reference_key ], unique: true
  end
end
