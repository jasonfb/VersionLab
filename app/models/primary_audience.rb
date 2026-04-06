# == Schema Information
#
# Table name: primary_audiences
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class PrimaryAudience < ApplicationRecord
  has_many :brand_profile_primary_audiences
  has_many :brand_profiles, through: :brand_profile_primary_audiences
  validates :name, presence: true
  default_scope { order(:position) }
end
