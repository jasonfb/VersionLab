# == Schema Information
#
# Table name: ai_logs
# Database name: primary
#
#  id                :uuid             not null, primary key
#  _cost_to_us_cents :integer
#  call_type         :enum             not null
#  completion_tokens :integer
#  loggable_type     :string
#  prompt            :text
#  prompt_tokens     :integer
#  response          :text
#  total_tokens      :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :uuid             not null
#  ai_model_id       :uuid
#  ai_service_id     :uuid
#  loggable_id       :uuid
#
# Indexes
#
#  idx_ai_logs_on_loggable      (loggable_type,loggable_id)
#  index_ai_logs_on_account_id  (account_id)
#  index_ai_logs_on_created_at  (created_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class AiLog < ApplicationRecord
  belongs_to :account
  belongs_to :ai_service, optional: true
  belongs_to :ai_model, optional: true
  belongs_to :loggable, polymorphic: true, optional: true

  enum :call_type, { email: "email", campaign_summary: "campaign_summary", email_summary: "email_summary", ad: "ad", audience_summary: "audience_summary" }, prefix: false

  before_create :compute_cost
  after_create :update_usage_summary

  private

  def compute_cost
    return unless ai_model&.input_cost_per_mtok_cents && ai_model&.output_cost_per_mtok_cents

    self._input_cost_cents  = BigDecimal(prompt_tokens.to_i.to_s)     * ai_model.input_cost_per_mtok_cents  / 1_000_000
    self._output_cost_cents = BigDecimal(completion_tokens.to_i.to_s) * ai_model.output_cost_per_mtok_cents / 1_000_000
    self._cost_to_us_cents  = _input_cost_cents + _output_cost_cents
  end

  def update_usage_summary
    return unless ai_model_id.present?

    month = created_at.beginning_of_month.to_date

    AiUsageSummary.upsert(
      {
        account_id: account_id,
        ai_model_id: ai_model_id,
        usage_month: month,
        _input_tokens: prompt_tokens.to_i,
        _output_tokens: completion_tokens.to_i,
        _total_tokens: total_tokens.to_i,
        _input_cost_cents: _input_cost_cents || 0,
        _output_cost_cents: _output_cost_cents || 0,
        _cost_to_us_cents: _cost_to_us_cents || 0,
        created_at: Time.current,
        updated_at: Time.current
      },
      unique_by: :idx_ai_usage_summaries_account_model_month,
      on_duplicate: Arel.sql(
        "_input_tokens = ai_usage_summaries._input_tokens + EXCLUDED._input_tokens, " \
        "_output_tokens = ai_usage_summaries._output_tokens + EXCLUDED._output_tokens, " \
        "_total_tokens = ai_usage_summaries._total_tokens + EXCLUDED._total_tokens, " \
        "_input_cost_cents = ai_usage_summaries._input_cost_cents + EXCLUDED._input_cost_cents, " \
        "_output_cost_cents = ai_usage_summaries._output_cost_cents + EXCLUDED._output_cost_cents, " \
        "_cost_to_us_cents = ai_usage_summaries._cost_to_us_cents + EXCLUDED._cost_to_us_cents, " \
        "updated_at = EXCLUDED.updated_at"
      )
    )
  end
end
