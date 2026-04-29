class CreateAdShapes < ActiveRecord::Migration[8.1]
  def change
    create_table :ad_shapes, id: :uuid do |t|
      t.string :name, null: false
      t.float :min_ratio, null: false
      t.float :max_ratio, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :ad_shapes, :name, unique: true
    add_index :ad_shapes, :position
  end
end
