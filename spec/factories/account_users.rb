FactoryBot.define do
  factory :account_user do
    account
    user
    is_owner { false }
    is_admin { false }
    is_billing_admin { false }
  end
end
