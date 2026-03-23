class CreateAds < ActiveRecord::Migration[8.1]
  def change
    create_table :ads, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.uuid :client_id, null: false
      t.string :name, null: false
      t.column :state, :ad_state, default: "setup", null: false
      t.column :background_type, :ad_background_type, default: "solid_color"
      t.string :background_color, default: "#000000"
      t.uuid :background_asset_id
      t.boolean :overlay_enabled, default: false, null: false
      t.column :overlay_type, :ad_overlay_type, default: "solid"
      t.string :overlay_color, default: "#FFFFFF"
      t.integer :overlay_opacity, default: 80
      t.boolean :play_button_enabled, default: false, null: false
      t.string :play_button_style, default: "circle_filled"
      t.string :play_button_color, default: "#FFFFFF"
      t.column :versioning_mode, :ad_versioning_mode, default: "retain_existing"
      t.uuid :campaign_id
      t.text :nlp_prompt
      t.boolean :keep_background, default: true, null: false
      t.column :output_format, :ad_output_format, default: "png"
      t.uuid :ai_service_id
      t.uuid :ai_model_id
      t.integer :width
      t.integer :height
      t.string :aspect_ratio
      t.jsonb :parsed_layers, default: []
      t.jsonb :file_warnings, default: []
      t.timestamps
    end

    add_index :ads, :client_id
    add_foreign_key :ads, :clients
  end
end
