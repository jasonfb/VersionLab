FactoryBot.define do
  factory :ai_service do
    sequence(:name) { |n| "AI Service #{n}" }
    sequence(:slug) { |n| "ai-service-#{n}" }
  end
end
