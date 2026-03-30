FactoryBot.define do
  factory :payment do
    account
    amount_cents { 4900 }
    status { "succeeded" }
    description { "Standard monthly subscription" }
    sequence(:stripe_payment_intent_id) { |n| "pi_test_#{n}" }
  end
end
