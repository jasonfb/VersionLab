# == Schema Information
#
# Table name: geographies
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Geography < ApplicationRecord
  has_many :brand_profile_geographies
  has_many :brand_profiles, through: :brand_profile_geographies
  validates :name, presence: true
  default_scope { order(:position) }
end
