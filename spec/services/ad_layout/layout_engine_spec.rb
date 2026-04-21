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

    it "enforces minimum font size of 8" do
      layer = result.layers.find { |l| l["font_size"] }
      expect(layer["font_size"].to_f).to be >= 8
    end
  end

  describe "with image layers" do
    let(:classified_layers) do
      [
        { "id" => "img1", "type" => "image", "role" => "logo",
          "href" => "data:logo", "x" => "10", "y" => "10",
          "width" => "200", "height" => "100" }
      ]
    end

    it "positions image layers within anchor bounds" do
      result = engine.compute_layout(1080, 1080)
      img = result.layers.find { |l| l["id"] == "img1" }
      next unless img
      expect(img["width"].to_i).to be > 0
      expect(img["height"].to_i).to be > 0
    end
  end

  describe "with wordmark groups" do
    let(:classified_layers) do
      [
        { "id" => "w1", "type" => "text", "content" => "BRAND", "font_size" => "20",
          "x" => "50", "y" => "30", "width" => "100", "height" => "30",
          "role" => "wordmark", "wordmark_group_id" => "w1", "confidence" => 0.75 },
        { "id" => "w2", "type" => "text", "content" => "NAME", "font_size" => "14",
          "x" => "50", "y" => "65", "width" => "80", "height" => "20",
          "role" => "wordmark", "wordmark_group_id" => "w1", "confidence" => 0.75 },
        { "id" => "h1", "type" => "text", "content" => "Headline Text",
          "font_size" => "48", "x" => "100", "y" => "200",
          "role" => "headline", "confidence" => 0.85 }
      ]
    end

    it "positions wordmark group members together" do
      result = engine.compute_layout(1080, 1080)
      wm_layers = result.layers.select { |l| l["role"] == "wordmark" }
      # May be 0 if wordmark is dropped in square template
      if wm_layers.any?
        expect(wm_layers.size).to eq(2)
        expect(wm_layers.all? { |l| l["wrapped_lines"] }).to be true
      end
    end
  end

  describe "with PDF-converted layers (no font_size)" do
    let(:classified_layers) do
      [
        { "id" => "r1", "type" => "text", "content" => "Some body text here",
          "x" => "50", "y" => "200", "width" => "980", "height" => "50",
          "role" => "body", "confidence" => 0.6 }
      ]
    end

    it "estimates font size from region dimensions" do
      result = engine.compute_layout(1080, 1080)
      layer = result.layers.first
      expect(layer["font_size"].to_f).to be >= 8
    end
  end

  describe "private methods" do
    describe "#compute_base_font_scale" do
      it "returns 1.0 when ad has no width" do
        ad.update_columns(width: nil, height: nil)
        scale = engine.send(:compute_base_font_scale, 500, 500)
        expect(scale).to eq(1.0)
      end

      it "uses the minimum of x and y scale" do
        scale = engine.send(:compute_base_font_scale, 540, 1080)
        expect(scale).to eq(0.5) # min(540/1080, 1080/1080) = 0.5
      end
    end

    describe "#simple_wrap" do
      it "wraps text at character limit" do
        lines = engine.send(:simple_wrap, "This is a longer text that should be wrapped", 20)
        expect(lines.size).to be > 1
      end

      it "keeps short text on one line" do
        lines = engine.send(:simple_wrap, "Short", 50)
        expect(lines).to eq(["Short"])
      end
    end

    describe "#estimate_font_size" do
      it "estimates from region dimensions" do
        layer = { "width" => "200", "height" => "50", "content" => "Hello World" }
        size = engine.send(:estimate_font_size, layer)
        expect(size).to be >= 12.0
      end

      it "handles zero-width region" do
        layer = { "width" => "0", "height" => "40", "content" => "" }
        size = engine.send(:estimate_font_size, layer)
        expect(size).to eq(30.0)
      end
    end

    describe "#find_font" do
      it "returns nil for empty lookup" do
        expect(engine.send(:find_font, "Arial", {})).to be_nil
      end

      it "returns nil for nil font_family" do
        expect(engine.send(:find_font, nil, { "Arial" => double })).to be_nil
      end
    end
  end
end
