class RenameEncryptedApiKeyToApiKeyOnAiKeys < ActiveRecord::Migration[8.1]
  def change
    rename_column :ai_keys, :encrypted_api_key, :api_key
  end
end
