# == Schema Information
#
# Table name: ai_services
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_ai_services_on_slug  (slug) UNIQUE
#
class AiService < ApplicationRecord
  has_many :ai_models, dependent: :destroy
  has_one :ai_key, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
end
