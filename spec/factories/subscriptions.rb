# == Schema Information
#
# Table name: subscriptions
# Database name: primary
#
#  id                    :uuid             not null, primary key
#  billing_interval      :enum             not null
#  canceled_date         :date
#  credit_applied_cents  :integer
#  paid_through_date     :date             not null
#  prorated_refund_cents :integer
#  start_date            :date             not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :uuid             not null
#  subscription_tier_id  :uuid             not null
#
# Indexes
#
#  index_subscriptions_on_account_id            (account_id)
#  index_subscriptions_on_subscription_tier_id  (subscription_tier_id)
#
FactoryBot.define do
  factory :subscription do
    account
    subscription_tier
    billing_interval { "monthly" }
    start_date { Date.current }
    paid_through_date { Date.current + 30.days }
  end
end
