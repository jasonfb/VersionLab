class AdShapeLayoutRule < ApplicationRecord
  ROLES = %w[headline subhead body cta logo decoration].freeze
  ALIGNMENTS = %w[left center right].freeze

  belongs_to :ad_shape

  validates :role, presence: true, uniqueness: { scope: :ad_shape_id }
  validates :position, presence: true

  # When not dropped, anchor coordinates and font_scale are required
  validates :anchor_x, :anchor_y, :anchor_w, :anchor_h, :font_scale, :align,
            presence: true, unless: :drop?

  scope :ordered, -> { order(:position) }
  scope :placed, -> { where(drop: false) }
  scope :dropped, -> { where(drop: true) }

  def to_label
    "#{role}#{' (dropped)' if drop?}"
  end

  def anchor
    return nil if drop?
    { x: anchor_x, y: anchor_y, w: anchor_w, h: anchor_h }
  end
end
