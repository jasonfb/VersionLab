# == Schema Information
#
# Table name: tone_rules
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class ToneRule < ApplicationRecord
  has_many :brand_profile_tone_rules
  has_many :brand_profiles, through: :brand_profile_tone_rules
  validates :name, presence: true
  default_scope { order(:position) }
end
