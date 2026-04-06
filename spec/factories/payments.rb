# == Schema Information
#
# Table name: payments
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  amount_cents             :integer          not null
#  currency                 :string           default("usd"), not null
#  description              :string
#  failure_reason           :text
#  status                   :enum             not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :uuid             not null
#  payment_method_id        :uuid
#  stripe_payment_intent_id :string
#  subscription_id          :uuid
#
# Indexes
#
#  index_payments_on_account_id                (account_id)
#  index_payments_on_stripe_payment_intent_id  (stripe_payment_intent_id) UNIQUE
#  index_payments_on_subscription_id           (subscription_id)
#
FactoryBot.define do
  factory :payment do
    account
    amount_cents { 4900 }
    status { "succeeded" }
    description { "Standard monthly subscription" }
    sequence(:stripe_payment_intent_id) { |n| "pi_test_#{n}" }
  end
end
