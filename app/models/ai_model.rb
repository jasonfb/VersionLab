# == Schema Information
#
# Table name: ai_models
# Database name: primary
#
#  id                         :uuid             not null, primary key
#  api_identifier             :string           not null
#  for_image                  :boolean          default(FALSE), not null
#  for_text                   :boolean          default(FALSE), not null
#  input_cost_per_mtok_cents  :integer
#  name                       :string           not null
#  output_cost_per_mtok_cents :integer
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  ai_service_id              :uuid             not null
#
# Indexes
#
#  index_ai_models_on_ai_service_id  (ai_service_id)
#
class AiModel < ApplicationRecord
  belongs_to :ai_service
  has_many :ai_usage_summaries, dependent: :destroy

  validates :name, presence: true
  validates :api_identifier, presence: true

  scope :for_text, -> { where(for_text: true) }
  scope :for_image, -> { where(for_image: true) }
end
