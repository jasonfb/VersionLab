FactoryBot.define do
  factory :ad_version do
    ad
    audience
    ai_service
    ai_model
    state { "generating" }
    sequence(:version_number) { |n| n }
  end
end
