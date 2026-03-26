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

  def self.deduplicated_sizes(selected_platforms)
    by_dims = {}

    selected_platforms.each do |platform_name|
      sizes = PLATFORMS[platform_name] || []
      sizes.each do |size|
        key = "#{size[:width]}x#{size[:height]}"
        by_dims[key] ||= { width: size[:width], height: size[:height], labels: [] }
        by_dims[key][:labels] << { "platform" => platform_name, "size_name" => size[:name] }
      end
    end

    by_dims.values
  end
end
