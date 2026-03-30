FactoryBot.define do
  factory :subscription do
    account
    subscription_tier
    billing_interval { "monthly" }
    start_date { Date.current }
    paid_through_date { Date.current + 30.days }
  end
end
