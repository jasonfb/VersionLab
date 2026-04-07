# == Schema Information
#
# Table name: users
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  name                   :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :user_roles
  has_many :roles, through: :user_roles

  has_many :account_users
  has_many :accounts, through: :account_users
  has_many :client_users, dependent: :destroy
  has_many :clients, through: :client_users

  def to_label
    email
  end

  scope :reverse_sort, -> { order(created_at:  :desc) }

  def admin?
    roles.exists?(name: "admin")
  end
end
