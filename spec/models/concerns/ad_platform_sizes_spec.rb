require 'rails_helper'

RSpec.describe AdPlatformSizes do
  describe "PLATFORMS" do
    it "contains expected platforms" do
      expect(AdPlatformSizes::PLATFORMS.keys).to include(
        "Facebook (Meta)", "Google Display", "Instagram", "LinkedIn",
        "Pinterest", "Reddit", "Snapchat", "Threads", "TikTok", "X", "YouTube"
      )
    end

    it "has valid size entries with name, width, and height" do
      AdPlatformSizes::PLATFORMS.each do |platform, sizes|
        sizes.each do |size|
          expect(size).to have_key(:name), "#{platform} has a size without :name"
          expect(size).to have_key(:width), "#{platform} #{size[:name]} missing :width"
          expect(size).to have_key(:height), "#{platform} #{size[:name]} missing :height"
          expect(size[:width]).to be > 0
          expect(size[:height]).to be > 0
        end
      end
    end
  end

  describe ".deduplicated_sizes" do
    it "returns unique sizes by dimensions" do
      # Facebook Feed Image (1080x1080) and Instagram Feed Square (1080x1080) should merge
      result = described_class.deduplicated_sizes([ "Facebook (Meta)", "Instagram" ])
      dims_1080 = result.select { |r| r[:width] == 1080 && r[:height] == 1080 }
      expect(dims_1080.length).to eq(1)
    end

    it "merges labels from multiple platforms with same dimensions" do
      result = described_class.deduplicated_sizes([ "Facebook (Meta)", "Instagram" ])
      entry = result.find { |r| r[:width] == 1080 && r[:height] == 1080 }
      platforms = entry[:labels].map { |l| l["platform"] }
      expect(platforms).to include("Facebook (Meta)", "Instagram")
    end

    it "returns empty array for unknown platforms" do
      result = described_class.deduplicated_sizes([ "Unknown" ])
      expect(result).to eq([])
    end

    it "returns empty array for empty input" do
      result = described_class.deduplicated_sizes([])
      expect(result).to eq([])
    end

    it "preserves unique sizes across platforms" do
      result = described_class.deduplicated_sizes([ "Facebook (Meta)" ])
      widths = result.map { |r| "#{r[:width]}x#{r[:height]}" }
      expect(widths).to include("1080x1080", "1080x1920", "1200x628")
    end
  end
end
