class AddAiFieldsToMerges < ActiveRecord::Migration[8.1]
  def change
    add_column :merges, :ai_service_id, :uuid
    add_column :merges, :ai_model_id, :uuid
  end
end
