require "rails_helper"

RSpec.describe AdLayout::LayoutEngine do
  let(:ad) do
    create(:ad,
      width: 1080,
      height: 1080,
      parsed_layers: parsed_layers,
      classified_layers: classified_layers,
      classifications_confirmed: true
    )
  end

  let(:parsed_layers) do
    [
      { "id" => "layer_0", "type" => "text", "content" => "Big Sale", "font_size" => "48", "font_family" => "Roboto-Bold", "x" => "100", "y" => "100" },
      { "id" => "layer_1", "type" => "text", "content" => "Up to 50% off everything in store", "font_size" => "24", "font_family" => "Roboto-Medium", "x" => "100", "y" => "250" },
      { "id" => "layer_2", "type" => "text", "content" => "Shop Now", "font_size" => "20", "font_family" => "Roboto-Bold", "x" => "400", "y" => "800" }
    ]
  end

  let(:classified_layers) do
    [
      { "id" => "layer_0", "type" => "text", "content" => "Big Sale", "font_size" => "48", "font_family" => "Roboto-Bold", "x" => "100", "y" => "100", "role" => "headline", "confidence" => 0.85 },
      { "id" => "layer_1", "type" => "text", "content" => "Up to 50% off everything in store", "font_size" => "24", "font_family" => "Roboto-Medium", "x" => "100", "y" => "250", "role" => "subhead", "confidence" => 0.7 },
      { "id" => "layer_2", "type" => "text", "content" => "Shop Now", "font_size" => "20", "font_family" => "Roboto-Bold", "x" => "400", "y" => "800", "role" => "cta", "confidence" => 0.9 }
    ]
  end

  subject(:engine) { described_class.new(ad) }

  describe "#compute_layout for same-size target (square → square)" do
    let(:result) { engine.compute_layout(1080, 1080) }

    it "returns a Result with layers" do
      expect(result).to be_a(AdLayout::LayoutEngine::Result)
      expect(result.layers).to be_an(Array)
      expect(result.layers.length).to eq(3)
    end

    it "classifies the bucket as square" do
      expect(result.bucket).to eq(:square)
    end

    it "positions layers within the canvas" do
      result.layers.each do |layer|
        expect(layer["x"].to_f).to be >= 0
        expect(layer["y"].to_f).to be >= 0
        expect(layer["x"].to_f).to be < 1080
        expect(layer["y"].to_f).to be < 1080
      end
    end

    it "assigns wrapped_lines to text layers" do
      result.layers.each do |layer|
        next unless layer["type"] == "text"
        expect(layer["wrapped_lines"]).to be_an(Array)
        expect(layer["wrapped_lines"]).not_to be_empty
      end
    end

    it "preserves alignment from template" do
      headline = result.layers.find { |l| l["role"] == "headline" }
      expect(headline["align"]).to eq("center")
    end
  end

  describe "#compute_layout for leaderboard target" do
    let(:result) { engine.compute_layout(728, 90) }

    it "classifies as leaderboard" do
      expect(result.bucket).to eq(:leaderboard)
    end

    it "drops subhead (not in placed_roles)" do
      roles = result.layers.map { |l| l["role"] }
      expect(roles).to include("headline", "cta")
      expect(roles).not_to include("subhead")
    end

    it "scales font sizes down significantly" do
      headline = result.layers.find { |l| l["role"] == "headline" }
      # 728/1080 = 0.674, 90/1080 = 0.083 → min_scale ~0.083, * font_scale 0.75
      expect(headline["font_size"].to_f).to be < 10
    end
  end

  describe "#compute_layout for story target" do
    let(:result) { engine.compute_layout(1080, 1920) }

    it "classifies as story" do
      expect(result.bucket).to eq(:story)
    end

    it "includes all three roles" do
      roles = result.layers.map { |l| l["role"] }
      expect(roles).to include("headline", "subhead", "cta")
    end

    it "scales headline font up (font_scale 1.1)" do
      headline = result.layers.find { |l| l["role"] == "headline" }
      # min_scale = min(1080/1080, 1920/1080) = 1.0, * 1.1 = 1.1
      # 48 * 1.0 * 1.1 = 52.8
      expect(headline["font_size"].to_f).to be_within(1).of(52.8)
    end
  end

  describe "legacy fallback" do
    let(:unclassified_ad) do
      create(:ad,
        width: 1080,
        height: 1080,
        parsed_layers: parsed_layers,
        classified_layers: [],
        classifications_confirmed: false
      )
    end

    let(:result) { described_class.new(unclassified_ad).compute_layout(540, 540) }

    it "uses proportional scaling" do
      # 540/1080 = 0.5 scale factor
      layer = result.layers.find { |l| l["id"] == "layer_0" }
      expect(layer["x"]).to eq("50") # 100 * 0.5
      expect(layer["y"]).to eq("50")
      expect(layer["font_size"]).to eq("24") # 48 * 0.5
    end

    it "still classifies the bucket" do
      expect(result.bucket).to eq(:square)
    end
  end
end
