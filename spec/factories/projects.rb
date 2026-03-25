FactoryBot.define do
  factory :project do
    account
    sequence(:name) { |n| "Project #{n}" }
    hidden { false }
  end
end
