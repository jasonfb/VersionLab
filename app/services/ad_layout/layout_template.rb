module AdLayout
  class LayoutTemplate
    # Element priority order (highest first). Elements are placed in this order;
    # lower-priority elements may be dropped if space runs out.
    PRIORITY = %w[headline cta logo subhead body decoration].freeze

    # Returns the template hash for a given shape, structured like the old
    # TEMPLATES constant: { role_sym => { anchor:, font_scale:, align:, drop: } }
    def self.for_shape(shape)
      shape_record = AdShape.find_by(name: shape.to_s)
      raise ArgumentError, "Unknown shape: #{shape}. Valid shapes: #{AdShape.ordered.pluck(:name).join(', ')}" unless shape_record

      shape_record.ad_shape_layout_rules.ordered.each_with_object({}) do |rule, hash|
        if rule.drop?
          hash[rule.role.to_sym] = { drop: true }
        else
          hash[rule.role.to_sym] = {
            anchor: { x: rule.anchor_x, y: rule.anchor_y, w: rule.anchor_w, h: rule.anchor_h },
            font_scale: rule.font_scale,
            align: rule.align
          }
        end
      end
    end

    # Legacy alias
    def self.for_bucket(shape)
      for_shape(shape)
    end

    # Returns the template entry for a specific role within a shape.
    def self.for_role(shape, role)
      template = for_shape(shape)
      template[role.to_sym]
    end

    # Returns the ordered list of roles that should be placed (not dropped) for a shape.
    def self.placed_roles(shape)
      shape_record = AdShape.find_by!(name: shape.to_s)
      placed = shape_record.ad_shape_layout_rules.placed.pluck(:role)
      PRIORITY.select { |role| placed.include?(role) }
    end

    # Returns the ordered list of roles that are dropped for a shape.
    def self.dropped_roles(shape)
      shape_record = AdShape.find_by!(name: shape.to_s)
      dropped = shape_record.ad_shape_layout_rules.dropped.pluck(:role)
      PRIORITY.select { |role| dropped.include?(role) }
    end

    # Converts a percentage-based anchor to pixel coordinates for given canvas dimensions.
    def self.anchor_to_pixels(anchor, canvas_width, canvas_height)
      {
        x: (anchor[:x] * canvas_width).round,
        y: (anchor[:y] * canvas_height).round,
        w: (anchor[:w] * canvas_width).round,
        h: (anchor[:h] * canvas_height).round,
      }
    end
  end
end
