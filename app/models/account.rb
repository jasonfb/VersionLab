class Account < ApplicationRecord

  has_many :assets, dependent: :destroy
  has_many :email_templates, dependent: :destroy
  has_many :account_users, dependent: :destroy
  has_many :users, through: :account_users
end
