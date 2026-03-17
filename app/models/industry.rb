class Industry < ApplicationRecord
  has_many :brand_profiles
  validates :name, presence: true
  default_scope { order(:position) }
end
