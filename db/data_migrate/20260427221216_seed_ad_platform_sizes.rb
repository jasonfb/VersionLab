class SeedAdPlatformSizes < ActiveRecord::Migration[8.1]
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

  def up
    PLATFORMS.each_with_index do |(platform_name, sizes), platform_index|
      platform = AdPlatform.find_or_create_by!(name: platform_name) do |p|
        p.position = platform_index
      end

      sizes.each_with_index do |size, size_index|
        AdPlatformSize.find_or_create_by!(ad_platform: platform, name: size[:name]) do |s|
          s.width = size[:width]
          s.height = size[:height]
          s.position = size_index
        end
      end
    end
  end

  def down
    AdPlatformSize.delete_all
    AdPlatform.delete_all
  end
end
