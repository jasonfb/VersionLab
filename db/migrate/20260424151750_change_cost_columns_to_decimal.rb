class ChangeCostColumnsToDecimal < ActiveRecord::Migration[8.1]
  def up
    change_column :ai_logs, :_cost_to_us_cents, :decimal, precision: 12, scale: 6
    change_column :ai_usage_summaries, :_cost_to_us_cents, :decimal, precision: 12, scale: 6
  end

  def down
    change_column :ai_logs, :_cost_to_us_cents, :integer
    change_column :ai_usage_summaries, :_cost_to_us_cents, :integer, default: 0, null: false
  end
end
