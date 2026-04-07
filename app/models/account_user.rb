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
class AccountUser < ApplicationRecord
  belongs_to :account
  belongs_to :user

  def to_label
    "#{user_id}"
  end

  def role_label
    return "Owner" if is_owner?
    return "Admin" if is_admin?
    return "Billing Admin" if is_billing_admin?
    "Member"
  end
end
