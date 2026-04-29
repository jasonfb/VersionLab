FactoryBot.define do
  factory :ad_shape do
    sequence(:name) { |n| "Shape #{n}" }
    min_ratio { 0.85 }
    max_ratio { 1.15 }
    sequence(:position) { |n| n }
  end
end
