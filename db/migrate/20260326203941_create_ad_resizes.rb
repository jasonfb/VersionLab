class CreateAdResizes < ActiveRecord::Migration[8.1]
  def change
    create_table :ad_resizes, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.uuid :ad_id, null: false
      t.jsonb :platform_labels, default: [], null: false
      t.integer :width, null: false
      t.integer :height, null: false
      t.string :aspect_ratio
      t.column :state, :ad_resize_state, default: "pending", null: false
      t.jsonb :resized_layers, default: []
      t.jsonb :layer_overrides, default: {}
      t.timestamps
    end

    add_index :ad_resizes, :ad_id
    add_index :ad_resizes, [ :ad_id, :width, :height ], unique: true
    add_foreign_key :ad_resizes, :ads
  end
end
