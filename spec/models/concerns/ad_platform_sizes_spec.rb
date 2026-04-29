require 'rails_helper'

RSpec.describe AdPlatformSizes do
  before do
    # Seed platforms for tests
    [
      ["Facebook (Meta)", [
        { name: "Feed Image", width: 1080, height: 1080 },
        { name: "Story", width: 1080, height: 1920 },
        { name: "Landscape", width: 1200, height: 628 }
      ]],
      ["Google Display", [
        { name: "Leaderboard", width: 728, height: 90 },
        { name: "Medium Rectangle", width: 300, height: 250 }
      ]],
      ["Instagram", [
        { name: "Feed Square", width: 1080, height: 1080 },
        { name: "Feed Portrait", width: 1080, height: 1350 },
        { name: "Story", width: 1080, height: 1920 }
      ]],
      ["LinkedIn", [
        { name: "Single Image", width: 1200, height: 627 },
        { name: "Square", width: 1080, height: 1080 }
      ]]
    ].each_with_index do |(name, sizes), i|
      platform = AdPlatform.create!(name: name, position: i)
      sizes.each_with_index do |s, j|
        platform.ad_platform_sizes.create!(name: s[:name], width: s[:width], height: s[:height], position: j)
      end
    end
  end

  describe ".all_platforms" do
    it "returns all platforms with their sizes" do
      result = described_class.all_platforms
      expect(result.keys).to include("Facebook (Meta)", "Google Display", "Instagram", "LinkedIn")
      expect(result["Facebook (Meta)"].length).to eq(3)
      expect(result["Facebook (Meta)"].first).to include(name: "Feed Image", width: 1080, height: 1080)
    end
  end

  describe ".deduplicated_sizes" do
    it "returns unique sizes by dimensions" do
      # Facebook Feed Image (1080x1080) and Instagram Feed Square (1080x1080) should merge
      result = described_class.deduplicated_sizes(["Facebook (Meta)", "Instagram"])
      dims_1080 = result.select { |r| r[:width] == 1080 && r[:height] == 1080 }
      expect(dims_1080.length).to eq(1)
    end

    it "merges labels from multiple platforms with same dimensions" do
      result = described_class.deduplicated_sizes(["Facebook (Meta)", "Instagram"])
      entry = result.find { |r| r[:width] == 1080 && r[:height] == 1080 }
      platforms = entry[:labels].map { |l| l["platform"] }
      expect(platforms).to include("Facebook (Meta)", "Instagram")
    end

    it "returns empty array for unknown platforms" do
      result = described_class.deduplicated_sizes(["Unknown"])
      expect(result).to eq([])
    end

    it "returns empty array for empty input" do
      result = described_class.deduplicated_sizes([])
      expect(result).to eq([])
    end

    it "preserves unique sizes across platforms" do
      result = described_class.deduplicated_sizes(["Facebook (Meta)"])
      widths = result.map { |r| "#{r[:width]}x#{r[:height]}" }
      expect(widths).to include("1080x1080", "1080x1920", "1200x628")
    end

    it "accepts hash format with specific size names" do
      result = described_class.deduplicated_sizes({ "Facebook (Meta)" => ["Feed Image", "Story"] })
      expect(result.length).to eq(2)
      dims = result.map { |r| "#{r[:width]}x#{r[:height]}" }
      expect(dims).to include("1080x1080", "1080x1920")
    end

    it "includes custom sizes" do
      result = described_class.deduplicated_sizes([], custom_sizes: [{ label: "Banner", width: 800, height: 200 }])
      expect(result.length).to eq(1)
      expect(result.first[:labels].first).to eq("platform" => "Custom", "size_name" => "Banner")
    end
  end
end
