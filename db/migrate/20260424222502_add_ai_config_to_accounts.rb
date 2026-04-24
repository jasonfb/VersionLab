class AddAiConfigToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :customer_chooses_ai, :boolean, default: true, null: false
    add_column :accounts, :ai_service_id, :uuid
    add_column :accounts, :ai_model_id, :uuid

    add_foreign_key :accounts, :ai_services
    add_foreign_key :accounts, :ai_models
  end
end
