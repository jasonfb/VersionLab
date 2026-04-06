# == Schema Information
#
# Table name: payment_methods
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  card_brand               :string
#  card_exp_month           :integer
#  card_exp_year            :integer
#  card_last4               :string
#  is_default               :boolean          default(FALSE), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :uuid             not null
#  stripe_payment_method_id :string           not null
#
# Indexes
#
#  index_payment_methods_on_account_id                (account_id)
#  index_payment_methods_on_stripe_payment_method_id  (stripe_payment_method_id) UNIQUE
#
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
