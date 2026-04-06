# == Schema Information
#
# Table name: industries
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Industry < ApplicationRecord
  has_many :brand_profiles
  validates :name, presence: true
  default_scope { order(:position) }
end
