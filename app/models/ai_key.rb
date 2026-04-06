# == Schema Information
#
# Table name: ai_keys
# Database name: primary
#
#  id            :uuid             not null, primary key
#  api_key       :text             not null
#  label         :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ai_service_id :uuid             not null
#
# Indexes
#
#  index_ai_keys_on_ai_service_id  (ai_service_id) UNIQUE
#
class AiKey < ApplicationRecord
  belongs_to :ai_service

  validates :api_key, presence: true
  validates :ai_service_id, uniqueness: true

  def to_label
    return "" if new_record?
    ai_service.name + " " + api_key[-4..0]
  end
end
