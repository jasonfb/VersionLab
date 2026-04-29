FactoryBot.define do
  factory :ad_platform do
    sequence(:name) { |n| "Platform #{n}" }
    sequence(:position) { |n| n }
  end
end
