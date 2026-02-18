class Account < ApplicationRecord

  has_many :assets, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :account_users, dependent: :destroy
  has_many :users, through: :account_users
  has_many :ai_keys, dependent: :destroy
end
