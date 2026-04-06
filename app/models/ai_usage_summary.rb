class AiUsageSummary < ApplicationRecord
  belongs_to :account
  belongs_to :ai_model

  validates :usage_month, presence: true
  validates :ai_model_id, uniqueness: { scope: [:account_id, :usage_month] }
end
