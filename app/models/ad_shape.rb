class AdShape < ApplicationRecord
  has_many :ad_shape_layout_rules, dependent: :destroy
  has_many :ad_resizes
  has_many :custom_ad_sizes

  validates :name, presence: true, uniqueness: true
  validates :min_ratio, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :max_ratio, presence: true, numericality: { greater_than: 0 }
  validates :position, presence: true

  scope :ordered, -> { order(:position) }

  def to_label
    name
  end

  def layout_summary
    placed = ad_shape_layout_rules.placed.ordered
    dropped = ad_shape_layout_rules.dropped.ordered

    lines = placed.map do |rule|
      x_pct = (rule.anchor_x * 100).round
      y_pct = (rule.anchor_y * 100).round
      w_pct = (rule.anchor_w * 100).round
      h_pct = (rule.anchor_h * 100).round

      position = "positioned #{x_pct}% from the left and #{y_pct}% from the top"
      size = "#{w_pct}% wide and #{h_pct}% tall"
      font = rule.font_scale == 1.0 ? "at full font scale" : "at #{(rule.font_scale * 100).round}% font scale"
      align = "#{rule.align}-aligned"

      "The #{rule.role} is #{position}, #{size}, #{font}, #{align}."
    end

    if dropped.any?
      verb = dropped.size == 1 ? "is" : "are"
      lines << "#{dropped.map(&:role).join(', ').capitalize} #{verb} dropped (not shown) in this shape."
    end

    lines.join(" ")
  end
end
