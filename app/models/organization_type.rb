# == Schema Information
#
# Table name: organization_types
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class OrganizationType < ApplicationRecord
  has_many :brand_profiles
  validates :name, presence: true
  default_scope { order(:position) }
end
