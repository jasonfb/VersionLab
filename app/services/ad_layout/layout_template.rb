module AdLayout
  class LayoutTemplate
    # Element priority order (highest first). Elements are placed in this order;
    # lower-priority elements may be dropped if space runs out.
    PRIORITY = %w[headline cta wordmark logo subhead body decoration].freeze

    # Per-bucket layout definitions. All positions are percentages of canvas (0.0–1.0).
    # Each role gets:
    #   anchor:     { x:, y:, w:, h: } — bounding region as percentage of canvas
    #   font_scale: multiplier applied to the base font scaling factor
    #   align:      text alignment within the region (left, center, right)
    #   drop:       if true, element is dropped in this bucket (not enough space)
    TEMPLATES = {
      square: {
        wordmark:   { anchor: { x: 0.05, y: 0.04, w: 0.40, h: 0.10 }, font_scale: 1.0,  align: "left" },
        headline:   { anchor: { x: 0.05, y: 0.16, w: 0.90, h: 0.25 }, font_scale: 1.0,  align: "center" },
        subhead:    { anchor: { x: 0.05, y: 0.42, w: 0.90, h: 0.18 }, font_scale: 0.9,  align: "center" },
        body:       { anchor: { x: 0.08, y: 0.60, w: 0.84, h: 0.18 }, font_scale: 0.85, align: "center" },
        cta:        { anchor: { x: 0.25, y: 0.80, w: 0.50, h: 0.12 }, font_scale: 0.9,  align: "center" },
        logo:       { anchor: { x: 0.35, y: 0.93, w: 0.30, h: 0.05 }, font_scale: 0.8,  align: "center" },
        decoration: { anchor: { x: 0.0,  y: 0.0,  w: 1.0,  h: 1.0  }, font_scale: 1.0,  align: "center" },
      },

      landscape: {
        wordmark:   { anchor: { x: 0.03, y: 0.05, w: 0.25, h: 0.15 }, font_scale: 1.0,  align: "left" },
        headline:   { anchor: { x: 0.03, y: 0.22, w: 0.55, h: 0.30 }, font_scale: 0.95, align: "left" },
        subhead:    { anchor: { x: 0.03, y: 0.54, w: 0.55, h: 0.18 }, font_scale: 0.85, align: "left" },
        body:       { anchor: { x: 0.03, y: 0.74, w: 0.55, h: 0.18 }, font_scale: 0.8,  align: "left" },
        cta:        { anchor: { x: 0.62, y: 0.60, w: 0.34, h: 0.15 }, font_scale: 0.9,  align: "center" },
        logo:       { anchor: { x: 0.62, y: 0.08, w: 0.34, h: 0.15 }, font_scale: 0.8,  align: "right" },
        decoration: { anchor: { x: 0.0,  y: 0.0,  w: 1.0,  h: 1.0  }, font_scale: 1.0,  align: "center" },
      },

      leaderboard: {
        wordmark:   { drop: true },
        headline:   { anchor: { x: 0.02, y: 0.10, w: 0.40, h: 0.80 }, font_scale: 0.75, align: "left" },
        subhead:    { drop: true },
        body:       { drop: true },
        cta:        { anchor: { x: 0.62, y: 0.15, w: 0.25, h: 0.70 }, font_scale: 0.7,  align: "center" },
        logo:       { anchor: { x: 0.89, y: 0.15, w: 0.10, h: 0.70 }, font_scale: 0.6,  align: "center" },
        decoration: { drop: true },
      },

      portrait: {
        wordmark:   { anchor: { x: 0.05, y: 0.04, w: 0.40, h: 0.08 }, font_scale: 1.0,  align: "left" },
        headline:   { anchor: { x: 0.05, y: 0.14, w: 0.90, h: 0.20 }, font_scale: 1.0,  align: "center" },
        subhead:    { anchor: { x: 0.05, y: 0.36, w: 0.90, h: 0.13 }, font_scale: 0.9,  align: "center" },
        body:       { anchor: { x: 0.08, y: 0.51, w: 0.84, h: 0.20 }, font_scale: 0.85, align: "center" },
        cta:        { anchor: { x: 0.20, y: 0.74, w: 0.60, h: 0.10 }, font_scale: 0.9,  align: "center" },
        logo:       { anchor: { x: 0.30, y: 0.86, w: 0.40, h: 0.08 }, font_scale: 0.8,  align: "center" },
        decoration: { anchor: { x: 0.0,  y: 0.0,  w: 1.0,  h: 1.0  }, font_scale: 1.0,  align: "center" },
      },

      story: {
        wordmark:   { anchor: { x: 0.05, y: 0.04, w: 0.40, h: 0.08 }, font_scale: 1.0,  align: "left" },
        headline:   { anchor: { x: 0.05, y: 0.16, w: 0.90, h: 0.20 }, font_scale: 1.1,  align: "center" },
        subhead:    { anchor: { x: 0.08, y: 0.38, w: 0.84, h: 0.12 }, font_scale: 0.9,  align: "center" },
        body:       { anchor: { x: 0.08, y: 0.52, w: 0.84, h: 0.18 }, font_scale: 0.85, align: "center" },
        cta:        { anchor: { x: 0.15, y: 0.75, w: 0.70, h: 0.10 }, font_scale: 1.0,  align: "center" },
        logo:       { anchor: { x: 0.30, y: 0.90, w: 0.40, h: 0.06 }, font_scale: 0.8,  align: "center" },
        decoration: { anchor: { x: 0.0,  y: 0.0,  w: 1.0,  h: 1.0  }, font_scale: 1.0,  align: "center" },
      },

      skyscraper: {
        wordmark:   { anchor: { x: 0.10, y: 0.03, w: 0.80, h: 0.08 }, font_scale: 0.7,  align: "center" },
        headline:   { anchor: { x: 0.05, y: 0.13, w: 0.90, h: 0.13 }, font_scale: 0.7,  align: "center" },
        subhead:    { anchor: { x: 0.05, y: 0.28, w: 0.90, h: 0.10 }, font_scale: 0.6,  align: "center" },
        body:       { drop: true },
        cta:        { anchor: { x: 0.08, y: 0.70, w: 0.84, h: 0.10 }, font_scale: 0.65, align: "center" },
        logo:       { anchor: { x: 0.15, y: 0.85, w: 0.70, h: 0.08 }, font_scale: 0.6,  align: "center" },
        decoration: { drop: true },
      },
    }.freeze

    def self.for_bucket(bucket)
      TEMPLATES.fetch(bucket.to_sym) do
        raise ArgumentError, "Unknown bucket: #{bucket}. Valid buckets: #{TEMPLATES.keys.join(', ')}"
      end
    end

    # Returns the template entry for a specific role within a bucket.
    # Returns nil if the role is not defined in the template.
    def self.for_role(bucket, role)
      template = for_bucket(bucket)
      template[role.to_sym]
    end

    # Returns the ordered list of roles that should be placed (not dropped) for a bucket.
    def self.placed_roles(bucket)
      template = for_bucket(bucket)
      PRIORITY.select { |role| !template.dig(role.to_sym, :drop) }
    end

    # Returns the ordered list of roles that are dropped for a bucket.
    def self.dropped_roles(bucket)
      template = for_bucket(bucket)
      PRIORITY.select { |role| template.dig(role.to_sym, :drop) }
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
