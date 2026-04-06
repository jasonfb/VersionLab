class AiService < ApplicationRecord
  has_many :ai_models, dependent: :destroy
  has_one :ai_key, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
end
