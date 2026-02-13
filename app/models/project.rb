class Project < ApplicationRecord
  belongs_to :account
  has_many :email_templates, dependent: :destroy

  validates :name, presence: true
end
