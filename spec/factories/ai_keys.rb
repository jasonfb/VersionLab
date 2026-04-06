FactoryBot.define do
  factory :ai_key do
    ai_service
    sequence(:api_key) { |n| "sk-test-key-#{n}" }
  end
end
