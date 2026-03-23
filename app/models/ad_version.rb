class AdVersion < ApplicationRecord
  belongs_to :ad
  belongs_to :audience
  belongs_to :ai_service
  belongs_to :ai_model

  enum :state, { generating: "generating", active: "active", rejected: "rejected" }

  validates :version_number, presence: true

  scope :active, -> { where(state: "active") }
end
