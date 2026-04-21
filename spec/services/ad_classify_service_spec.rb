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

  describe "continuation detection" do
    let(:parsed_layers) do
      [
        { "id" => "h", "type" => "text", "content" => "HEADLINE", "font_size" => "48", "x" => "50", "y" => "100" },
        { "id" => "b1", "type" => "text", "content" => "This is a sentence that", "font_size" => "14", "x" => "50", "y" => "500",
          "font_family" => "Arial", "fill" => "#FFF" },
        { "id" => "b2", "type" => "text", "content" => "continues on next line", "font_size" => "14", "x" => "50", "y" => "520",
          "font_family" => "Arial", "fill" => "#FFF" }
      ]
    end

    it "links continuation fragments" do
      result = subject
      b2 = result.find { |l| l["id"] == "b2" }
      expect(b2["continuation_of"]).to eq("b1")
    end

    it "does not link when previous ends with terminator" do
      layers = parsed_layers.dup
      layers[1] = layers[1].merge("content" => "Complete sentence.")
      test_ad = create(:ad, width: 1080, height: 1080, parsed_layers: layers)
      result = described_class.new(test_ad).call
      b2 = result.find { |l| l["id"] == "b2" }
      expect(b2["continuation_of"]).to be_nil
    end

    it "does not link different font sizes" do
      layers = parsed_layers.dup
      layers[2] = layers[2].merge("font_size" => "24")
      test_ad = create(:ad, width: 1080, height: 1080, parsed_layers: layers)
      result = described_class.new(test_ad).call
      b2 = result.find { |l| l["id"] == "b2" }
      expect(b2["continuation_of"]).to be_nil
    end
  end

  describe "CTA background attachment" do
    let(:parsed_layers) do
      [
        { "id" => "h", "type" => "text", "content" => "Title", "font_size" => "48", "x" => "50", "y" => "50" },
        { "id" => "cta", "type" => "text", "content" => "Shop Now", "font_size" => "14", "x" => "100", "y" => "900" },
        { "id" => "btn", "type" => "shape", "shape" => "rect", "fill" => "#FF0000", "rx" => 8.0,
          "x" => "80", "y" => "880", "width" => "140", "height" => "40" }
      ]
    end

    it "attaches CTA background from enclosing shape" do
      result = subject
      cta = result.find { |l| l["id"] == "cta" }
      expect(cta["cta_background_color"]).to eq("#FF0000")
      expect(cta["cta_background_rx_ratio"]).to be > 0
    end
  end

  describe "non-text layer classification" do
    let(:parsed_layers) do
      [
        { "id" => "img1", "type" => "image", "href" => "data:img" },
        { "id" => "t1", "type" => "text", "content" => "Hello", "font_size" => "24", "x" => "10", "y" => "10" }
      ]
    end

    it "classifies images as logo" do
      result = subject
      img = result.find { |l| l["id"] == "img1" }
      expect(img["role"]).to eq("logo")
      expect(img["confidence"]).to eq(0.8)
    end
  end

  describe "wordmark detection" do
    let(:parsed_layers) do
      [
        { "id" => "w1", "type" => "text", "content" => "BRAND", "font_size" => "20", "x" => "50", "y" => "30",
          "font_family" => "Georgia", "fill" => "#000" },
        { "id" => "w2", "type" => "text", "content" => "NAME", "font_size" => "14", "x" => "50", "y" => "55",
          "font_family" => "Arial", "fill" => "#000" },
        { "id" => "h1", "type" => "text", "content" => "Main headline text here", "font_size" => "48", "x" => "50", "y" => "400" }
      ]
    end

    it "detects multi-member wordmark groups" do
      result = subject
      w1 = result.find { |l| l["id"] == "w1" }
      w2 = result.find { |l| l["id"] == "w2" }
      expect(w1["role"]).to eq("wordmark")
      expect(w2["role"]).to eq("wordmark")
      expect(w1["wordmark_group_id"]).to be_present
      expect(w2["wordmark_group_id"]).to eq(w1["wordmark_group_id"])
    end
  end
end
