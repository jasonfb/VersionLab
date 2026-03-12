class Project < ApplicationRecord
  belongs_to :account
  has_many :email_templates, dependent: :destroy
  has_many :audiences, dependent: :destroy
  has_many :assets, dependent: :destroy

  scope :visible, -> { where(hidden: false) }
  scope :hidden_projects, -> { where(hidden: true) }

  validates :name, presence: true
end
