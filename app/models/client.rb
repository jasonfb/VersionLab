class Client < ApplicationRecord
  belongs_to :account
  has_many :email_templates, dependent: :destroy
  has_many :emails, dependent: :destroy
  has_many :audiences, dependent: :destroy
  has_many :assets, dependent: :destroy
  has_many :campaigns, dependent: :destroy
  has_one :brand_profile, dependent: :destroy
  has_many :client_users, dependent: :destroy
  has_many :users, through: :client_users

  scope :visible, -> { where(hidden: false) }
  scope :hidden_clients, -> { where(hidden: true) }

  validates :name, presence: true
end
