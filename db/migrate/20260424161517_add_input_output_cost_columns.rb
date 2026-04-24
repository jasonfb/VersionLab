class AddInputOutputCostColumns < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_logs, :_input_cost_cents, :decimal, precision: 12, scale: 6
    add_column :ai_logs, :_output_cost_cents, :decimal, precision: 12, scale: 6

    add_column :ai_usage_summaries, :_input_cost_cents, :decimal, precision: 12, scale: 6, null: false, default: 0
    add_column :ai_usage_summaries, :_output_cost_cents, :decimal, precision: 12, scale: 6, null: false, default: 0
  end
end
