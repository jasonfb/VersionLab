# == Schema Information
#
# Table name: brand_profile_geographies
# Database name: primary
#
#  id               :uuid             not null, primary key
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  brand_profile_id :uuid             not null
#  geography_id     :uuid             not null
#
# Indexes
#
#  idx_bp_geographies  (brand_profile_id,geography_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (brand_profile_id => brand_profiles.id)
#  fk_rails_...  (geography_id => geographies.id)
#
class BrandProfileGeography < ApplicationRecord
  belongs_to :brand_profile
  belongs_to :geography
end
