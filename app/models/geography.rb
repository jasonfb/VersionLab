class Geography < ApplicationRecord
  has_many :brand_profile_geographies
  has_many :brand_profiles, through: :brand_profile_geographies
  validates :name, presence: true
  default_scope { order(:position) }
end
