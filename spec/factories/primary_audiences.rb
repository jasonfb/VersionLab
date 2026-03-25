FactoryBot.define do
  factory :primary_audience do
    sequence(:name) { |n| "Primary Audience #{n}" }
    sequence(:position) { |n| n }
  end
end
