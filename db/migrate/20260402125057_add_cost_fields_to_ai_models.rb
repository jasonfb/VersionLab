class AddCostFieldsToAiModels < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_models, :input_cost_per_mtok_cents, :integer
    add_column :ai_models, :output_cost_per_mtok_cents, :integer
  end
end
