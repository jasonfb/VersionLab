# == Schema Information
#
# Table name: campaigns
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  ai_summary              :text
#  ai_summary_generated_at :datetime
#  ai_summary_state        :enum             default("idle"), not null
#  description             :text
#  end_date                :date
#  goals                   :text
#  name                    :string           not null
#  start_date              :date
#  status                  :enum             default("draft"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  client_id               :uuid             not null
#
# Indexes
#
#  index_campaigns_on_client_id  (client_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_id => clients.id)
#
FactoryBot.define do
  factory :campaign do
    client
    sequence(:name) { |n| "Campaign #{n}" }
    status { "draft" }
    ai_summary_state { "idle" }
  end
end
