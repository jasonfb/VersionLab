module AdLayout
  class AspectRatioBucket
    # Classify target dimensions into a shape name (e.g. :square, :leaderboard).
    # Queries AdShape records ordered by position; falls back to :square.
    def self.classify(width, height)
      return :square unless width.to_f > 0 && height.to_f > 0

      ratio = width.to_f / height.to_f

      shape = AdShape.ordered.find { |s| ratio >= s.min_ratio && ratio < s.max_ratio }
      shape&.name&.to_sym || :square
    end

    def self.all_shapes
      AdShape.ordered.pluck(:name).map(&:to_sym)
    end

    # Legacy alias
    def self.all_buckets
      all_shapes
    end
  end
end
