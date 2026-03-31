require "rails_helper"

RSpec.describe AdLayout::AspectRatioBucket do
  describe ".classify" do
    # Square
    { "1080x1080 (1:1)" => [1080, 1080, :square],
      "600x600 (1:1)" => [600, 600, :square],
      "1200x1080 (~1.11:1)" => [1200, 1080, :square],

      # Landscape
      "1200x628 (~1.91:1, Facebook)" => [1200, 628, :landscape],
      "1920x1080 (16:9)" => [1920, 1080, :landscape],
      "1200x900 (4:3)" => [1200, 900, :landscape],
      "1200x627 (LinkedIn)" => [1200, 627, :landscape],

      # Leaderboard
      "728x90 (Google Leaderboard)" => [728, 90, :leaderboard],
      "970x250 (Billboard)" => [970, 250, :leaderboard],
      "970x90 (Large Leaderboard)" => [970, 90, :leaderboard],

      # Portrait
      "1080x1350 (4:5, Instagram)" => [1080, 1350, :portrait],
      "1000x1500 (2:3, Pinterest)" => [1000, 1500, :portrait],

      # Story
      "1080x1920 (9:16, Instagram Story)" => [1080, 1920, :story],

      # Skyscraper
      "160x600 (Wide Skyscraper)" => [160, 600, :skyscraper],
      "120x600 (Skyscraper)" => [120, 600, :skyscraper],
      "300x1050 (Portrait)" => [300, 1050, :skyscraper],
    }.each do |label, (w, h, expected)|
      it "classifies #{label} as #{expected}" do
        expect(described_class.classify(w, h)).to eq(expected)
      end
    end

    it "returns :square for zero dimensions" do
      expect(described_class.classify(0, 0)).to eq(:square)
    end

    it "returns :square for nil dimensions" do
      expect(described_class.classify(nil, nil)).to eq(:square)
    end
  end

  describe ".all_buckets" do
    it "returns all 6 bucket names" do
      expect(described_class.all_buckets).to eq(
        [:leaderboard, :landscape, :square, :portrait, :story, :skyscraper]
      )
    end
  end
end
