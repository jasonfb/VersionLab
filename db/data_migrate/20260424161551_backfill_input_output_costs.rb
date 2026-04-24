class BackfillInputOutputCosts < ActiveRecord::Migration[8.1]
  def up
    # Step 1: backfill ai_logs
    execute <<~SQL
      UPDATE ai_logs
      SET _input_cost_cents  = (ai_logs.prompt_tokens::numeric     * ai_models.input_cost_per_mtok_cents)  / 1000000,
          _output_cost_cents = (ai_logs.completion_tokens::numeric * ai_models.output_cost_per_mtok_cents) / 1000000
      FROM ai_models
      WHERE ai_logs.ai_model_id = ai_models.id
        AND ai_models.input_cost_per_mtok_cents  IS NOT NULL
        AND ai_models.output_cost_per_mtok_cents IS NOT NULL
    SQL

    # Step 2: rebuild ai_usage_summaries from ai_logs
    execute <<~SQL
      UPDATE ai_usage_summaries
      SET _input_cost_cents  = agg.input_cost,
          _output_cost_cents = agg.output_cost
      FROM (
        SELECT account_id, ai_model_id,
               DATE_TRUNC('month', created_at)::date AS usage_month,
               COALESCE(SUM(_input_cost_cents), 0)   AS input_cost,
               COALESCE(SUM(_output_cost_cents), 0)  AS output_cost
        FROM ai_logs
        WHERE _input_cost_cents IS NOT NULL
        GROUP BY account_id, ai_model_id, DATE_TRUNC('month', created_at)::date
      ) agg
      WHERE ai_usage_summaries.account_id  = agg.account_id
        AND ai_usage_summaries.ai_model_id = agg.ai_model_id
        AND ai_usage_summaries.usage_month = agg.usage_month
    SQL
  end

  def down
    execute "UPDATE ai_logs            SET _input_cost_cents = NULL, _output_cost_cents = NULL"
    execute "UPDATE ai_usage_summaries SET _input_cost_cents = 0,    _output_cost_cents = 0"
  end
end
