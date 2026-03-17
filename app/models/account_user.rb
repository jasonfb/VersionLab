class AccountUser < ApplicationRecord
  belongs_to :account
  belongs_to :user

  def role_label
    return "Owner" if is_owner?
    return "Admin" if is_admin?
    return "Billing Admin" if is_billing_admin?
    "Member"
  end
end
