# == Schema Information
#
# Table name: ai_keys
# Database name: primary
#
#  id            :uuid             not null, primary key
#  api_key       :text             not null
#  label         :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ai_service_id :uuid             not null
#
# Indexes
#
#  index_ai_keys_on_ai_service_id  (ai_service_id) UNIQUE
#
FactoryBot.define do
  factory :ai_key do
    ai_service
    sequence(:api_key) { |n| "sk-test-key-#{n}" }
  end
end
