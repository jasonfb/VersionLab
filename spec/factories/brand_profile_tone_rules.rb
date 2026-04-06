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
FactoryBot.define do
  factory :brand_profile_tone_rule do
    brand_profile
    tone_rule
  end
end
