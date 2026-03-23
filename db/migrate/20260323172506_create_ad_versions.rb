class CreateAdVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :ad_versions, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.uuid :ad_id, null: false
      t.uuid :audience_id, null: false
      t.integer :version_number, default: 1, null: false
      t.column :state, :ad_version_state, default: "generating", null: false
      t.text :rejection_comment
      t.jsonb :generated_layers, default: []
      t.uuid :ai_service_id, null: false
      t.uuid :ai_model_id, null: false
      t.timestamps
    end

    add_index :ad_versions, [ :ad_id, :audience_id ]
    add_index :ad_versions, [ :ad_id, :audience_id, :version_number ], unique: true
    add_foreign_key :ad_versions, :ads
    add_foreign_key :ad_versions, :audiences
  end
end
