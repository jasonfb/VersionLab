# == Schema Information
#
# Table name: brand_profile_tone_rules
# Database name: primary
#
#  id               :uuid             not null, primary key
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  brand_profile_id :uuid             not null
#  tone_rule_id     :uuid             not null
#
# Indexes
#
#  idx_bp_tone_rules  (brand_profile_id,tone_rule_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (brand_profile_id => brand_profiles.id)
#  fk_rails_...  (tone_rule_id => tone_rules.id)
#
require 'rails_helper'

RSpec.describe BrandProfileToneRule, type: :model do
  describe "associations" do
    it "belongs to brand_profile" do
      assoc = described_class.reflect_on_association(:brand_profile)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to tone_rule" do
      assoc = described_class.reflect_on_association(:tone_rule)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end
end
