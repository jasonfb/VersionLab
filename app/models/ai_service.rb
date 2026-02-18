class AiService < ApplicationRecord
  has_many :ai_models, dependent: :destroy
  has_many :ai_keys, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
end
