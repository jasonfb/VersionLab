class AdPlatformSize < ApplicationRecord
  belongs_to :ad_platform

  validates :name, presence: true, uniqueness: { scope: :ad_platform_id }
  validates :width, presence: true, numericality: { greater_than: 0 }
  validates :height, presence: true, numericality: { greater_than: 0 }
  validates :position, presence: true

  scope :ordered, -> { order(:position) }

  def to_label
    "#{name} (#{width}x#{height})"
  end

  def shape
    AdLayout::AspectRatioBucket.classify(width, height)
  end
end
