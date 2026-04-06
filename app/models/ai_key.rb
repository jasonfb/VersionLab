class AiKey < ApplicationRecord
  belongs_to :ai_service

  validates :api_key, presence: true
  validates :ai_service_id, uniqueness: true
end
