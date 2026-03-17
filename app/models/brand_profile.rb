class BrandProfile < ApplicationRecord
  belongs_to :client
  belongs_to :organization_type, optional: true
  belongs_to :industry, optional: true

  has_many :brand_profile_primary_audiences, dependent: :destroy
  has_many :primary_audiences, through: :brand_profile_primary_audiences

  has_many :brand_profile_tone_rules, dependent: :destroy
  has_many :tone_rules, through: :brand_profile_tone_rules

  has_many :brand_profile_geographies, dependent: :destroy
  has_many :geographies, through: :brand_profile_geographies
end
