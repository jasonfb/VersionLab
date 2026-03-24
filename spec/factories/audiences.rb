FactoryBot.define do
  factory :audience do
    sequence(:name) { |n| "Audience #{n}" }
    association :client
  end
end
