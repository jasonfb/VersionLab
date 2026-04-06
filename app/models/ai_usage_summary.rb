# == Schema Information
#
# Table name: ai_usage_summaries
# Database name: primary
#
#  id                :uuid             not null, primary key
#  _cost_to_us_cents :integer          default(0), not null
#  _input_tokens     :bigint           default(0), not null
#  _output_tokens    :bigint           default(0), not null
#  _total_tokens     :bigint           default(0), not null
#  usage_month       :date             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :uuid             not null
#  ai_model_id       :uuid             not null
#
# Indexes
#
#  idx_ai_usage_summaries_account_model_month  (account_id,ai_model_id,usage_month) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (ai_model_id => ai_models.id)
#
class AiUsageSummary < ApplicationRecord
  belongs_to :account
  belongs_to :ai_model

  validates :usage_month, presence: true
  validates :ai_model_id, uniqueness: { scope: [:account_id, :usage_month] }
end
