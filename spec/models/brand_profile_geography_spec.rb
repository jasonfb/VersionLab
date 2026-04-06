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
require 'rails_helper'

RSpec.describe BrandProfileGeography, type: :model do
  describe "associations" do
    it "belongs to brand_profile" do
      assoc = described_class.reflect_on_association(:brand_profile)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to geography" do
      assoc = described_class.reflect_on_association(:geography)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end
end
