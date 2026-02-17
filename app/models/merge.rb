class Merge < ApplicationRecord
  belongs_to :email_template
  has_many :merge_audiences, dependent: :destroy
  has_many :audiences, through: :merge_audiences

  validates :state, inclusion: { in: %w[setup pending merged] }

  delegate :project, to: :email_template
end
