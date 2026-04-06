class RemoveAccountIdFromAiKeys < ActiveRecord::Migration[8.1]
  def change
    remove_index :ai_keys, name: :index_ai_keys_on_account_id_and_ai_service_id
    remove_column :ai_keys, :account_id, :uuid, null: false
    add_index :ai_keys, :ai_service_id, unique: true
  end
end
