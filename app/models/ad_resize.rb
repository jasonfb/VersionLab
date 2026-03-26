class AdResize < ApplicationRecord
  belongs_to :ad
  has_many :ad_versions, dependent: :nullify

  has_one_attached :preview_image
  has_one_attached :resized_svg

  enum :state, { pending: "pending", resized: "resized", failed: "failed" }

  validates :width, :height, presence: true, numericality: { greater_than: 0 }
  validates :platform_labels, presence: true

  def label
    platform_labels.map { |pl| "#{pl['platform']} #{pl['size_name']}" }.join(", ")
  end

  def dimensions
    "#{width}x#{height}"
  end
end
