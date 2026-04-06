# == Schema Information
#
# Table name: clients
# Database name: primary
#
#  id         :uuid             not null, primary key
#  hidden     :boolean          default(FALSE), not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :uuid             not null
#
class Client < ApplicationRecord
  belongs_to :account
  has_many :ads, dependent: :destroy
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
