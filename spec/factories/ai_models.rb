FactoryBot.define do
  factory :ai_model do
    ai_service
    sequence(:name) { |n| "AI Model #{n}" }
    sequence(:api_identifier) { |n| "model-#{n}" }
    for_text { true }
    for_image { false }
  end
end
