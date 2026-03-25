FactoryBot.define do
  factory :organization_type do
    sequence(:name) { |n| "Organization Type #{n}" }
    sequence(:position) { |n| n }
  end
end
