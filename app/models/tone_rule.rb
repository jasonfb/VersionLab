class ToneRule < ApplicationRecord
  has_many :brand_profile_tone_rules
  has_many :brand_profiles, through: :brand_profile_tone_rules
  validates :name, presence: true
  default_scope { order(:position) }
end
