class CreateAdShapeLayoutRules < ActiveRecord::Migration[8.1]
  def change
    create_table :ad_shape_layout_rules, id: :uuid do |t|
      t.uuid :ad_shape_id, null: false
      t.string :role, null: false
      t.float :anchor_x
      t.float :anchor_y
      t.float :anchor_w
      t.float :anchor_h
      t.float :font_scale
      t.string :align
      t.boolean :drop, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_foreign_key :ad_shape_layout_rules, :ad_shapes
    add_index :ad_shape_layout_rules, :ad_shape_id
    add_index :ad_shape_layout_rules, [:ad_shape_id, :role], unique: true
  end
end
