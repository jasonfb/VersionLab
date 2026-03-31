require "rails_helper"

RSpec.describe AdClassifyService do
  let(:ad) { create(:ad, width: 1080, height: 1080, parsed_layers: parsed_layers) }
  subject { described_class.new(ad).call }

  describe "headline detection" do
    let(:parsed_layers) do
      [
        { "id" => "layer_0", "type" => "text", "content" => "Big Sale Today", "font_size" => "48", "x" => "100", "y" => "100" },
        { "id" => "layer_1", "type" => "text", "content" => "Up to 50% off everything in store", "font_size" => "24", "x" => "100", "y" => "200" },
        { "id" => "layer_2", "type" => "text", "content" => "Terms and conditions apply", "font_size" => "12", "x" => "100", "y" => "900" }
      ]
    end

    it "classifies the largest text as headline" do
      result = subject
      headline = result.find { |l| l["id"] == "layer_0" }
      expect(headline["role"]).to eq("headline")
      expect(headline["confidence"]).to be >= 0.8
    end

    it "classifies the second largest as subhead" do
      result = subject
      subhead = result.find { |l| l["id"] == "layer_1" }
      expect(subhead["role"]).to eq("subhead")
    end

    it "classifies remaining text as body" do
      result = subject
      body = result.find { |l| l["id"] == "layer_2" }
      expect(body["role"]).to eq("body")
    end
  end

  describe "CTA detection" do
    let(:parsed_layers) do
      [
        { "id" => "layer_0", "type" => "text", "content" => "Summer Collection", "font_size" => "48", "x" => "100", "y" => "100" },
        { "id" => "layer_1", "type" => "text", "content" => "Shop Now", "font_size" => "24", "x" => "400", "y" => "800" }
      ]
    end

    it "classifies short action text as CTA" do
      result = subject
      cta = result.find { |l| l["id"] == "layer_1" }
      expect(cta["role"]).to eq("cta")
      expect(cta["confidence"]).to eq(0.9)
    end

    it "does not classify the headline as CTA" do
      result = subject
      headline = result.find { |l| l["id"] == "layer_0" }
      expect(headline["role"]).to eq("headline")
    end
  end

  describe "CTA pattern matching" do
    %w[Shop\ Now Learn\ More Click\ Here Sign\ Up Get\ Started Buy\ Now].each do |cta_text|
      it "recognizes '#{cta_text}' as a CTA" do
        layers = [
          { "id" => "layer_0", "type" => "text", "content" => "Headline", "font_size" => "48", "x" => "0", "y" => "0" },
          { "id" => "layer_1", "type" => "text", "content" => cta_text, "font_size" => "20", "x" => "0", "y" => "500" }
        ]
        test_ad = create(:ad, width: 1080, height: 1080, parsed_layers: layers)
        result = described_class.new(test_ad).call
        cta = result.find { |l| l["id"] == "layer_1" }
        expect(cta["role"]).to eq("cta")
      end
    end
  end

  describe "background detection" do
    let(:parsed_layers) do
      [
        { "id" => "bg_0", "type" => "rect", "content" => "", "x" => "0", "y" => "0", "width" => "1080", "height" => "1080" },
        { "id" => "layer_0", "type" => "text", "content" => "Hello World", "font_size" => "36", "x" => "100", "y" => "100" }
      ]
    end

    it "classifies full-canvas non-text elements as decoration (non-text fallback)" do
      result = subject
      bg = result.find { |l| l["id"] == "bg_0" }
      expect(bg["role"]).to eq("decoration")
    end
  end

  describe "background detection for text layers with dimensions" do
    let(:parsed_layers) do
      [
        { "id" => "layer_0", "type" => "text", "content" => "Background overlay", "font_size" => "12", "x" => "0", "y" => "0", "width" => "1080", "height" => "1080" },
        { "id" => "layer_1", "type" => "text", "content" => "Main Text", "font_size" => "48", "x" => "100", "y" => "100" }
      ]
    end

    it "classifies full-canvas text elements as background" do
      result = subject
      bg = result.find { |l| l["id"] == "layer_0" }
      expect(bg["role"]).to eq("background")
    end
  end

  describe "single text layer" do
    let(:parsed_layers) do
      [
        { "id" => "layer_0", "type" => "text", "content" => "Only Text", "font_size" => "36", "x" => "100", "y" => "100" }
      ]
    end

    it "classifies a single text layer as headline with lower confidence" do
      result = subject
      expect(result.first["role"]).to eq("headline")
      expect(result.first["confidence"]).to eq(0.7)
    end
  end

  describe "empty layers" do
    let(:parsed_layers) { [] }

    it "returns an empty array" do
      expect(subject).to eq([])
    end
  end

  describe "persistence" do
    let(:parsed_layers) do
      [
        { "id" => "layer_0", "type" => "text", "content" => "Title", "font_size" => "48", "x" => "0", "y" => "0" }
      ]
    end

    it "saves classified_layers to the ad record" do
      subject
      ad.reload
      expect(ad.classified_layers).to be_present
      expect(ad.classified_layers.first["role"]).to eq("headline")
    end

    it "does not modify parsed_layers" do
      original = ad.parsed_layers.deep_dup
      subject
      ad.reload
      expect(ad.parsed_layers).to eq(original)
    end
  end
end
