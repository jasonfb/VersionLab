# == Schema Information
#
# Table name: account_users
# Database name: primary
#
#  id               :uuid             not null, primary key
#  is_admin         :boolean          default(FALSE), not null
#  is_billing_admin :boolean          default(FALSE), not null
#  is_owner         :boolean
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :uuid
#  user_id          :uuid
#
FactoryBot.define do
  factory :account_user do
    account
    user
    is_owner { false }
    is_admin { false }
    is_billing_admin { false }
  end
end
