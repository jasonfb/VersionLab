require "rails_helper"

RSpec.describe "Ad Layout Engine — end-to-end integration", type: :model do
  include_context "seeded ad shapes"

  let(:ad) do
    ad = create(:ad,
      width: 1080,
      height: 1080,
      parsed_layers: [
        { "id" => "layer_0", "type" => "text", "content" => "Summer Sale", "font_size" => "48", "font_family" => "Roboto-Bold", "x" => "100", "y" => "100" },
        { "id" => "layer_1", "type" => "text", "content" => "Get 30% off all items this weekend only", "font_size" => "24", "font_family" => "Roboto-Medium", "x" => "100", "y" => "250" },
        { "id" => "layer_2", "type" => "text", "content" => "Shop Now", "font_size" => "20", "font_family" => "Roboto-Bold", "x" => "400", "y" => "800" }
      ],
      background_color: "#1a1a1a"
    )
    ad.file.attach(
      io: File.open(Rails.root.join("spec/fixtures/files/1_SolidBkg_StaticType.pdf")),
      filename: "test.pdf",
      content_type: "application/pdf"
    )
    ad
  end

  describe "full pipeline: classify → resize → SVG output" do
    before do
      # Step 1: Auto-classify
      AdClassifyService.new(ad).call
      ad.reload
    end

    it "auto-classifies layers with roles and confidence" do
      expect(ad.classified_layers).to be_present
      expect(ad.classified_layers.length).to eq(3)

      roles = ad.classified_layers.map { |l| l["role"] }
      expect(roles).to include("headline")
      expect(roles).to include("cta")

      ad.classified_layers.each do |layer|
        expect(layer["confidence"]).to be_a(Numeric)
        expect(layer["confidence"]).to be > 0
      end
    end

    it "preserves parsed_layers unchanged" do
      expect(ad.parsed_layers.length).to eq(3)
      ad.parsed_layers.each do |layer|
        expect(layer).not_to have_key("role")
        expect(layer).not_to have_key("confidence")
      end
    end

    context "after confirming classifications" do
      before do
        ad.update!(classifications_confirmed: true)
      end

      it "computes layout for square (same aspect ratio)" do
        engine = AdLayout::LayoutEngine.new(ad)
        result = engine.compute_layout(1080, 1080)

        expect(result.shape).to eq(:square)
        expect(result.layers.length).to eq(3)

        headline = result.layers.find { |l| l["role"] == "headline" }
        expect(headline["wrapped_lines"]).to be_present
        expect(headline["align"]).to eq("center")
      end

      it "computes layout for leaderboard (extreme aspect ratio change)" do
        engine = AdLayout::LayoutEngine.new(ad)
        result = engine.compute_layout(728, 90)

        expect(result.shape).to eq(:leaderboard)

        roles = result.layers.map { |l| l["role"] }
        expect(roles).to include("headline")
        expect(roles).to include("cta")
        expect(roles).not_to include("subhead") # dropped in leaderboard
      end

      it "computes layout for story (tall format)" do
        engine = AdLayout::LayoutEngine.new(ad)
        result = engine.compute_layout(1080, 1920)

        expect(result.shape).to eq(:story)
        expect(result.layers.length).to eq(3) # all three roles placed in story
      end

      it "generates valid SVG via SvgComposer" do
        engine = AdLayout::LayoutEngine.new(ad)
        result = engine.compute_layout(728, 90)

        svg_string = AdLayout::SvgComposer.new(ad).compose(result)
        doc = Nokogiri::XML(svg_string) { |config| config.strict }
        root = doc.at_css("svg")

        expect(root["width"]).to eq("728")
        expect(root["height"]).to eq("90")
        expect(root["viewBox"]).to eq("0 0 728 90")

        # Background rect
        bg = doc.at_css("rect")
        expect(bg["fill"]).to eq("#1a1a1a")

        # Text elements for placed roles
        texts = doc.css("text")
        expect(texts.length).to be >= 2 # headline + cta

        # Font sizes are reasonable for a 90px tall banner
        texts.each do |t|
          size = t["font-size"].to_f
          expect(size).to be >= 8  # minimum
          expect(size).to be <= 90 # can't exceed canvas height
        end
      end

      it "generates valid SVG for all 6 shape types" do
        targets = {
          square:      [1080, 1080],
          landscape:   [1920, 1080],
          leaderboard: [728, 90],
          portrait:    [1080, 1350],
          story:       [1080, 1920],
          skyscraper:  [160, 600],
        }

        engine = AdLayout::LayoutEngine.new(ad)
        composer = AdLayout::SvgComposer.new(ad)

        targets.each do |shape, (w, h)|
          result = engine.compute_layout(w, h)
          expect(result.shape).to eq(shape), "Expected #{w}x#{h} to be #{shape}, got #{result.shape}"

          svg_string = composer.compose(result)
          doc = Nokogiri::XML(svg_string) { |config| config.strict }
          root = doc.at_css("svg")

          expect(root["width"]).to eq(w.to_s), "SVG width mismatch for #{shape}"
          expect(root["height"]).to eq(h.to_s), "SVG height mismatch for #{shape}"

          # At least headline and CTA should be present (except where dropped)
          texts = doc.css("text")
          expect(texts.length).to be >= 1, "No text elements in #{shape} SVG"
        end
      end
    end
  end

  describe "backwards compatibility: unclassified ad" do
    let(:legacy_ad) do
      create(:ad,
        width: 1080,
        height: 1080,
        parsed_layers: [
          { "id" => "layer_0", "type" => "text", "content" => "Old Ad", "font_size" => "36", "x" => "200", "y" => "300" }
        ],
        classified_layers: [],
        classifications_confirmed: false,
        background_color: "#000000"
      )
    end

    it "uses legacy proportional scaling" do
      engine = AdLayout::LayoutEngine.new(legacy_ad)
      result = engine.compute_layout(540, 540)

      expect(result.layers.length).to eq(1)
      layer = result.layers.first
      expect(layer["x"]).to eq("100") # 200 * 0.5
      expect(layer["y"]).to eq("150") # 300 * 0.5
      expect(layer["font_size"]).to eq("18") # 36 * 0.5
    end

    it "does not produce wrapped_lines" do
      engine = AdLayout::LayoutEngine.new(legacy_ad)
      result = engine.compute_layout(540, 540)

      layer = result.layers.first
      expect(layer).not_to have_key("wrapped_lines")
    end

    it "does not add role or align fields" do
      engine = AdLayout::LayoutEngine.new(legacy_ad)
      result = engine.compute_layout(540, 540)

      layer = result.layers.first
      expect(layer).not_to have_key("role")
      expect(layer).not_to have_key("align")
    end
  end
end
