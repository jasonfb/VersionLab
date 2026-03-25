FactoryBot.define do
  factory :geography do
    sequence(:name) { |n| "Geography #{n}" }
    sequence(:position) { |n| n }
  end
end
