class MergeVersion < ApplicationRecord
  belongs_to :merge
  belongs_to :audience
  belongs_to :ai_service
  belongs_to :ai_model
  has_many :merge_version_variables, dependent: :destroy

  enum :state, { generating: "generating", active: "active", rejected: "rejected" }

  validates :version_number, presence: true
end
