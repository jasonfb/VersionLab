class CreateAiUsageSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_usage_summaries, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :ai_model_id, null: false
      t.date :usage_month, null: false
      t.bigint :_input_tokens, null: false, default: 0
      t.bigint :_output_tokens, null: false, default: 0
      t.bigint :_total_tokens, null: false, default: 0
      t.integer :_cost_to_us_cents, null: false, default: 0
      t.timestamps
    end

    add_index :ai_usage_summaries, [:account_id, :ai_model_id, :usage_month], unique: true, name: :idx_ai_usage_summaries_account_model_month
    add_foreign_key :ai_usage_summaries, :accounts
    add_foreign_key :ai_usage_summaries, :ai_models
  end
end
