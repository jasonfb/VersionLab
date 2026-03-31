require "rails_helper"

RSpec.describe AdLayout::SvgComposer do
  let(:ad) do
    create(:ad,
      width: 1080,
      height: 1080,
      background_color: "#1a1a1a",
      classifications_confirmed: true,
      classified_layers: [
        { "id" => "layer_0", "type" => "text", "content" => "Big Sale", "font_size" => "48", "role" => "headline" },
        { "id" => "layer_1", "type" => "text", "content" => "Shop Now", "font_size" => "20", "role" => "cta" }
      ]
    )
  end

  subject(:composer) { described_class.new(ad) }

  describe "#compose" do
    let(:layout_result) do
      AdLayout::LayoutEngine.new(ad).compute_layout(1080, 1080)
    end

    let(:svg_string) { composer.compose(layout_result) }
    let(:doc) { Nokogiri::XML(svg_string) }
    let(:root) { doc.at_css("svg") }

    it "produces valid XML" do
      expect { Nokogiri::XML(svg_string) { |config| config.strict } }.not_to raise_error
    end

    it "sets correct dimensions on the SVG root" do
      expect(root["width"]).to eq("1080")
      expect(root["height"]).to eq("1080")
      expect(root["viewBox"]).to eq("0 0 1080 1080")
    end

    it "renders a background rect" do
      rect = doc.at_css("rect")
      expect(rect).to be_present
      expect(rect["width"]).to eq("1080")
      expect(rect["height"]).to eq("1080")
      expect(rect["fill"]).to eq("#1a1a1a")
    end

    it "renders text elements for each text layer" do
      texts = doc.css("text")
      expect(texts.length).to eq(2)
    end

    it "includes the text content" do
      text_contents = doc.css("text").map { |t| t.text.strip }
      expect(text_contents).to include("Big Sale")
      expect(text_contents).to include("Shop Now")
    end

    it "sets font-size attributes" do
      doc.css("text").each do |text|
        expect(text["font-size"].to_f).to be > 0
      end
    end
  end

  describe "#compose for leaderboard" do
    let(:layout_result) do
      AdLayout::LayoutEngine.new(ad).compute_layout(728, 90)
    end

    let(:svg_string) { composer.compose(layout_result) }
    let(:doc) { Nokogiri::XML(svg_string) }

    it "sets leaderboard dimensions" do
      root = doc.at_css("svg")
      expect(root["width"]).to eq("728")
      expect(root["height"]).to eq("90")
    end

    it "only renders placed layers (drops subhead)" do
      texts = doc.css("text")
      # headline and cta are placed; subhead is not in classified_layers for this ad
      expect(texts.length).to be >= 1
    end
  end

  describe "#compose with wrapped lines" do
    let(:ad_with_long_text) do
      create(:ad,
        width: 1080,
        height: 1080,
        background_color: "#000000",
        classifications_confirmed: true,
        classified_layers: [
          { "id" => "layer_0", "type" => "text", "content" => "This is a very long headline that should wrap onto multiple lines", "font_size" => "48", "role" => "headline" }
        ]
      )
    end

    it "renders multiple tspan elements for wrapped text" do
      engine = AdLayout::LayoutEngine.new(ad_with_long_text)
      result = engine.compute_layout(300, 300)
      svg_string = described_class.new(ad_with_long_text).compose(result)
      doc = Nokogiri::XML(svg_string)

      tspans = doc.css("tspan")
      expect(tspans.length).to be > 1
    end
  end

  describe "center-aligned text" do
    let(:layout_result) do
      AdLayout::LayoutEngine.new(ad).compute_layout(1080, 1080)
    end

    let(:svg_string) { composer.compose(layout_result) }
    let(:doc) { Nokogiri::XML(svg_string) }

    it "sets text-anchor to middle for center-aligned layers" do
      headline_text = doc.css("text").first
      expect(headline_text["text-anchor"]).to eq("middle")
    end
  end
end
