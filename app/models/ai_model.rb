class AiModel < ApplicationRecord
  belongs_to :ai_service
  has_many :ai_usage_summaries, dependent: :destroy

  validates :name, presence: true
  validates :api_identifier, presence: true

  scope :for_text, -> { where(for_text: true) }
  scope :for_image, -> { where(for_image: true) }
end
