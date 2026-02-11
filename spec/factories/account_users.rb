FactoryBot.define do
  factory :account_user do
    account_id { "" }
    user_id { "" }
    is_owner { false }
  end
end
