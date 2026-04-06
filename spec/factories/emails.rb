# == Schema Information
#
# Table name: emails
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  ai_summary              :text
#  ai_summary_generated_at :datetime
#  ai_summary_state        :enum             default("idle"), not null
#  context                 :text
#  state                   :enum             default("setup"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  ai_model_id             :uuid
#  ai_service_id           :uuid
#  campaign_id             :uuid
#  client_id               :uuid             not null
#  email_template_id       :uuid             not null
#
# Indexes
#
#  index_emails_on_campaign_id  (campaign_id)
#  index_emails_on_client_id    (client_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#  fk_rails_...  (client_id => clients.id)
#
FactoryBot.define do
  factory :email do
    client
    email_template
    campaign { nil }
    ai_service { nil }
    ai_model { nil }
    state { "setup" }
    ai_summary_state { "idle" }
  end
end
