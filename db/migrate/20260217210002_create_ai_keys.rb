class CreateAiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_keys, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :ai_service_id, null: false
      t.text :encrypted_api_key, null: false
      t.string :label

      t.timestamps
    end

    add_index :ai_keys, [:account_id, :ai_service_id], unique: true
  end
end
