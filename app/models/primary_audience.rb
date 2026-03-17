class PrimaryAudience < ApplicationRecord
  has_many :brand_profile_primary_audiences
  has_many :brand_profiles, through: :brand_profile_primary_audiences
  validates :name, presence: true
  default_scope { order(:position) }
end
