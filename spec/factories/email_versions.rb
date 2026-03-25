FactoryBot.define do
  factory :email_version do
    email
    audience
    ai_service
    ai_model
    state { "generating" }
    sequence(:version_number) { |n| n }
  end
end
