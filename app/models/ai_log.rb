class AiLog < ApplicationRecord
  belongs_to :account
  belongs_to :ai_service, optional: true
  belongs_to :ai_model, optional: true
  belongs_to :loggable, polymorphic: true, optional: true

  enum :call_type, { email: "email", campaign_summary: "campaign_summary", email_summary: "email_summary" }, prefix: false
end
