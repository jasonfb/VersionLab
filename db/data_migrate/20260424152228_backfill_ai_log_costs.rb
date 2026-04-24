class BackfillAiLogCosts < ActiveRecord::Migration[8.1]
  def up
    # Step 1: backfill ai_logs in a single SQL UPDATE using a join to ai_models
    execute <<~SQL
      UPDATE ai_logs
      SET _cost_to_us_cents = (
        (ai_logs.prompt_tokens::numeric     * ai_models.input_cost_per_mtok_cents)  +
        (ai_logs.completion_tokens::numeric * ai_models.output_cost_per_mtok_cents)
      ) / 1000000
      FROM ai_models
      WHERE ai_logs.ai_model_id = ai_models.id
        AND ai_models.input_cost_per_mtok_cents  IS NOT NULL
        AND ai_models.output_cost_per_mtok_cents IS NOT NULL
    SQL

    # Step 2: rebuild ai_usage_summaries._cost_to_us_cents by summing the
    # now-correct ai_logs costs for each (account, model, month) group
    execute <<~SQL
      UPDATE ai_usage_summaries
      SET _cost_to_us_cents = aggregated.total_cost
      FROM (
        SELECT
          account_id,
          ai_model_id,
          DATE_TRUNC('month', created_at)::date AS usage_month,
          SUM(_cost_to_us_cents)                AS total_cost
        FROM ai_logs
        WHERE _cost_to_us_cents IS NOT NULL
        GROUP BY account_id, ai_model_id, DATE_TRUNC('month', created_at)::date
      ) aggregated
      WHERE ai_usage_summaries.account_id  = aggregated.account_id
        AND ai_usage_summaries.ai_model_id = aggregated.ai_model_id
        AND ai_usage_summaries.usage_month = aggregated.usage_month
    SQL
  end

  def down
    execute "UPDATE ai_logs             SET _cost_to_us_cents = NULL"
    execute "UPDATE ai_usage_summaries  SET _cost_to_us_cents = 0"
  end
end
