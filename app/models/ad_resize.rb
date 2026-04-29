# == Schema Information
#
# Table name: ad_resizes
# Database name: primary
#
#  id              :uuid             not null, primary key
#  aspect_ratio    :string
#  height          :integer          not null
#  layer_overrides :jsonb
#  platform_labels :jsonb            not null
#  resized_layers  :jsonb
#  state           :enum             default("pending"), not null
#  width           :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  ad_id           :uuid             not null
#
# Indexes
#
#  index_ad_resizes_on_ad_id                       (ad_id)
#  index_ad_resizes_on_ad_id_and_width_and_height  (ad_id,width,height) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ad_id => ads.id)
#
class AdResize < ApplicationRecord
  belongs_to :ad
  belongs_to :ad_shape, optional: true
  has_many :ad_versions, dependent: :nullify

  has_one_attached :preview_image
  has_one_attached :resized_svg

  enum :state, { pending: "pending", resized: "resized", failed: "failed" }

  LAYOUT_VARIANTS = %w[left center right].freeze

  validates :width, :height, presence: true, numericality: { greater_than: 0 }
  validates :platform_labels, presence: true
  validates :layout_variant, inclusion: { in: LAYOUT_VARIANTS }

  def label
    platform_labels.map { |pl| "#{pl['platform']} #{pl['size_name']}" }.join(", ")
  end

  def dimensions
    "#{width}x#{height}"
  end

  # Override chain: explicit ad_shape > computed from dimensions
  def effective_shape
    ad_shape&.name&.to_sym || AdLayout::AspectRatioBucket.classify(width, height)
  end
end
