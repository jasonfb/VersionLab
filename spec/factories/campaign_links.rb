FactoryBot.define do
  factory :campaign_link do
    campaign
    sequence(:url) { |n| "https://example.com/link-#{n}" }
  end
end
