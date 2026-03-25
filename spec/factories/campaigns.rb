FactoryBot.define do
  factory :campaign do
    client
    sequence(:name) { |n| "Campaign #{n}" }
    status { "draft" }
    ai_summary_state { "idle" }
  end
end
