module AdLayout
  class AspectRatioBucket
    # Buckets ordered from most extreme landscape to most extreme portrait.
    # Ratio = width / height. Ranges are inclusive on the low end, exclusive on the high end
    # except where noted.
    #
    # leaderboard:  ratio >= 3.5       (e.g. 728x90 = 8.09, 970x250 = 3.88)
    # landscape:    1.15 <= ratio < 3.5 (e.g. 16:9 = 1.78, 4:3 = 1.33)
    # square:       0.85 <= ratio < 1.15 (e.g. 1:1 = 1.0)
    # portrait:     0.45 <= ratio < 0.85 (e.g. 4:5 = 0.8, 2:3 = 0.67)
    # story:        0.3  <= ratio < 0.45 (e.g. 9:16 = 0.5625 — but some overlap, so story is narrower)
    # skyscraper:   ratio < 0.3          (e.g. 160x600 = 0.267, 120x600 = 0.2)
    #
    # Note: 9:16 (0.5625) falls in portrait range. Story is reserved for even taller formats.
    # Adjusted: story covers 0.45..0.65 to capture 9:16, portrait gets 0.65..0.85

    BUCKETS = [
      { name: :leaderboard, min_ratio: 3.5,  max_ratio: Float::INFINITY },
      { name: :landscape,   min_ratio: 1.15, max_ratio: 3.5 },
      { name: :square,      min_ratio: 0.85, max_ratio: 1.15 },
      { name: :portrait,    min_ratio: 0.65, max_ratio: 0.85 },
      { name: :story,       min_ratio: 0.45, max_ratio: 0.65 },
      { name: :skyscraper,  min_ratio: 0.0,  max_ratio: 0.45 },
    ].freeze

    def self.classify(width, height)
      return :square unless width.to_f > 0 && height.to_f > 0

      ratio = width.to_f / height.to_f

      bucket = BUCKETS.find { |b| ratio >= b[:min_ratio] && ratio < b[:max_ratio] }
      # Handle exact upper boundary for leaderboard (infinity)
      bucket ||= BUCKETS.last

      bucket[:name]
    end

    def self.all_buckets
      BUCKETS.map { |b| b[:name] }
    end
  end
end
