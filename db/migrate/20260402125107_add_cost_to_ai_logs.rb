class AddCostToAiLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_logs, :_cost_to_us_cents, :integer
  end
end
