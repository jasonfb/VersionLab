FactoryBot.define do
  factory :tone_rule do
    sequence(:name) { |n| "Tone Rule #{n}" }
    sequence(:position) { |n| n }
  end
end
