# == Schema Information
#
# Table name: brand_profile_primary_audiences
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  brand_profile_id    :uuid             not null
#  primary_audience_id :uuid             not null
#
# Indexes
#
#  idx_bp_primary_audiences  (brand_profile_id,primary_audience_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (brand_profile_id => brand_profiles.id)
#  fk_rails_...  (primary_audience_id => primary_audiences.id)
#
class BrandProfilePrimaryAudience < ApplicationRecord
  belongs_to :brand_profile
  belongs_to :primary_audience
end
