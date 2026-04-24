module AdPlatformSizes
  PLATFORMS = {
    "Facebook (Meta)" => [
      { name: "Feed Image",  width: 1080, height: 1080 },
      { name: "Story",       width: 1080, height: 1920 },
      { name: "Landscape",   width: 1200, height: 628  }
    ],
    "Google Display" => [
      { name: "Leaderboard",      width: 728,  height: 90  },
      { name: "Medium Rectangle", width: 300,  height: 250 },
      { name: "Large Rectangle",  width: 336,  height: 280 },
      { name: "Half Page",        width: 300,  height: 600 },
      { name: "Wide Skyscraper",  width: 160,  height: 600 }
    ],
    "Instagram" => [
      { name: "Feed Square",   width: 1080, height: 1080 },
      { name: "Feed Portrait", width: 1080, height: 1350 },
      { name: "Story",         width: 1080, height: 1920 }
    ],
    "LinkedIn" => [
      { name: "Single Image", width: 1200, height: 627 },
      { name: "Square",       width: 1080, height: 1080 }
    ],
    "Pinterest" => [
      { name: "Standard Pin", width: 1000, height: 1500 },
      { name: "Square Pin",   width: 1000, height: 1000 }
    ],
    "Reddit"   => [ { name: "Feed Image",  width: 1200, height: 628 } ],
    "Snapchat" => [ { name: "Full Screen", width: 1080, height: 1920 } ],
    "Threads"  => [ { name: "Feed Image",  width: 1080, height: 1080 } ],
    "TikTok"   => [ { name: "In-Feed",     width: 1080, height: 1920 } ],
    "X" => [
      { name: "Single Image", width: 1200, height: 675 },
      { name: "Square",       width: 1080, height: 1080 }
    ],
    "YouTube" => [
      { name: "Display Banner", width: 300, height: 250 },
      { name: "Overlay",        width: 480, height: 70  }
    ]
  }.freeze

  # selected_platforms can be:
  #   - Hash/object: { "Platform Name" => ["Size1", "Size2"] } for specific sizes
  #     (nil value means all sizes for that platform)
  #   - Array: ["Platform Name", ...] for all sizes (legacy)
  # custom_sizes is an optional array of { label:, width:, height: } hashes
  def self.deduplicated_sizes(selected_platforms, custom_sizes: [])
    by_dims = {}

    entries = if selected_platforms.is_a?(Hash)
      selected_platforms
    else
      Array(selected_platforms).index_with { |_| nil }
    end

    entries.each do |platform_name, size_names|
      all_sizes = PLATFORMS[platform_name] || []
      sizes = if size_names.present?
        all_sizes.select { |s| size_names.include?(s[:name]) }
      else
        all_sizes
      end

      sizes.each do |size|
        key = "#{size[:width]}x#{size[:height]}"
        by_dims[key] ||= { width: size[:width], height: size[:height], labels: [] }
        by_dims[key][:labels] << { "platform" => platform_name, "size_name" => size[:name] }
      end
    end

    Array(custom_sizes).each do |cs|
      w = cs[:width].to_i
      h = cs[:height].to_i
      next if w <= 0 || h <= 0

      key = "#{w}x#{h}"
      by_dims[key] ||= { width: w, height: h, labels: [] }
      by_dims[key][:labels] << { "platform" => "Custom", "size_name" => cs[:label].presence || key }
    end

    by_dims.values
  end
end
