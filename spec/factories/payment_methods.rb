FactoryBot.define do
  factory :payment_method do
    account
    sequence(:stripe_payment_method_id) { |n| "pm_test_#{n}" }
    card_brand { "visa" }
    card_last4 { "4242" }
    card_exp_month { 12 }
    card_exp_year { 2028 }
    is_default { false }
  end
end
