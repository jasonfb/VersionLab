class AiLog < ApplicationRecord
  belongs_to :account
  belongs_to :ai_service, optional: true
  belongs_to :ai_model, optional: true
  belongs_to :loggable, polymorphic: true, optional: true

  enum :call_type, { email: "email", campaign_summary: "campaign_summary", email_summary: "email_summary", ad: "ad" }, prefix: false

  before_create :compute_cost
  after_create :update_usage_summary

  private

  def compute_cost
    return unless ai_model&.input_cost_per_mtok_cents && ai_model&.output_cost_per_mtok_cents

    input_cost = (prompt_tokens.to_i * ai_model.input_cost_per_mtok_cents) / 1_000_000.0
    output_cost = (completion_tokens.to_i * ai_model.output_cost_per_mtok_cents) / 1_000_000.0
    self._cost_to_us_cents = (input_cost + output_cost).ceil
  end

  def update_usage_summary
    return unless ai_model_id.present?

    month = created_at.beginning_of_month.to_date
    cost = _cost_to_us_cents.to_i

    AiUsageSummary.upsert(
      {
        account_id: account_id,
        ai_model_id: ai_model_id,
        usage_month: month,
        _input_tokens: prompt_tokens.to_i,
        _output_tokens: completion_tokens.to_i,
        _total_tokens: total_tokens.to_i,
        _cost_to_us_cents: cost,
        created_at: Time.current,
        updated_at: Time.current
      },
      unique_by: :idx_ai_usage_summaries_account_model_month,
      on_duplicate: Arel.sql(
        "_input_tokens = ai_usage_summaries._input_tokens + EXCLUDED._input_tokens, " \
        "_output_tokens = ai_usage_summaries._output_tokens + EXCLUDED._output_tokens, " \
        "_total_tokens = ai_usage_summaries._total_tokens + EXCLUDED._total_tokens, " \
        "_cost_to_us_cents = ai_usage_summaries._cost_to_us_cents + EXCLUDED._cost_to_us_cents, " \
        "updated_at = EXCLUDED.updated_at"
      )
    )
  end
end
