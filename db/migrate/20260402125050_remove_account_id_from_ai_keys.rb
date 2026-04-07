class RemoveAccountIdFromAiKeys < ActiveRecord::Migration[8.1]
  def up
    remove_index :ai_keys, name: :index_ai_keys_on_account_id_and_ai_service_id
    execute "DELETE FROM ai_keys"
    remove_column :ai_keys, :account_id, :uuid
    add_index :ai_keys, :ai_service_id, unique: true
  end

  def down
    remove_index :ai_keys, :ai_service_id
    add_column :ai_keys, :account_id, :uuid, null: true
    add_index :ai_keys, [:account_id, :ai_service_id], name: :index_ai_keys_on_account_id_and_ai_service_id
  end
end
