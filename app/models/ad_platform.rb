class AdPlatform < ApplicationRecord
  has_many :ad_platform_sizes, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :position, presence: true

  scope :ordered, -> { order(:position) }

  def to_label
    name
  end
end
