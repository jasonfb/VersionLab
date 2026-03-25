FactoryBot.define do
  factory :industry do
    sequence(:name) { |n| "Industry #{n}" }
    sequence(:position) { |n| n }
  end
end
