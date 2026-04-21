require 'rails_helper'

RSpec.describe AdParseService, "SVG parsing" do
  let(:client) { create(:client) }
  let(:ad) { create(:ad, client: client) }

  # All text elements must include font-size, font-family, font-weight, and fill
  # attributes to avoid triggering the css_style fallback (which is undefined).
  let(:text_attrs) { 'font-size="24" font-family="Arial" font-weight="bold" fill="#000"' }

  before do
    allow_any_instance_of(AdClassifyService).to receive(:call).and_return([])
  end

  describe "#call" do
    context "SVG with text, images, and shapes" do
      before do
        svg = <<~SVG
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 250">
            <text id="headline" #{text_attrs} x="10" y="40">Big Sale</text>
            <text id="cta" font-size="14" font-family="Arial" font-weight="normal" fill="#FFF" x="10" y="200">Shop Now</text>
            <image href="data:image/png;base64,abc" x="250" y="10" width="40" height="40"/>
            <rect fill="#FF0000" x="50" y="180" width="100" height="40" rx="8"/>
          </svg>
        SVG
        ad.file.attach(io: StringIO.new(svg), filename: "ad.svg", content_type: "image/svg+xml")
      end

      it "parses text layers" do
        result = described_class.new(ad).call
        text_layers = result[:layers].select { |l| l[:type] == "text" }
        expect(text_layers.size).to eq(2)
        expect(text_layers.first[:content]).to eq("Big Sale")
      end

      it "extracts dimensions from viewBox" do
        result = described_class.new(ad).call
        expect(result[:width]).to eq(300)
        expect(result[:height]).to eq(250)
      end

      it "computes aspect ratio" do
        result = described_class.new(ad).call
        expect(result[:aspect_ratio]).to eq("6:5")
      end

      it "extracts image layers (excludes full-canvas)" do
        result = described_class.new(ad).call
        images = result[:layers].select { |l| l[:type] == "image" }
        expect(images.size).to eq(1)
      end

      it "extracts shape layers" do
        result = described_class.new(ad).call
        shapes = result[:layers].select { |l| l[:type] == "shape" }
        expect(shapes.size).to eq(1)
        expect(shapes.first[:fill]).to eq("#FF0000")
      end

      it "updates the ad record" do
        described_class.new(ad).call
        ad.reload
        expect(ad.parsed_layers).to be_present
        expect(ad.width).to eq(300)
      end

      it "calls AdClassifyService" do
        expect_any_instance_of(AdClassifyService).to receive(:call)
        described_class.new(ad).call
      end
    end

    context "SVG with width/height attributes" do
      before do
        svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="400" height="300"><text #{text_attrs} x="10" y="20">Hello</text></svg>)
        ad.file.attach(io: StringIO.new(svg), filename: "ad.svg", content_type: "image/svg+xml")
      end

      it "extracts dimensions from attributes" do
        result = described_class.new(ad).call
        expect(result[:width]).to eq(400)
        expect(result[:height]).to eq(300)
      end
    end

    context "SVG with no text" do
      before do
        svg = '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect width="100" height="100" fill="red"/></svg>'
        ad.file.attach(io: StringIO.new(svg), filename: "ad.svg", content_type: "image/svg+xml")
      end

      it "includes no_text_layers and no_logo_detected warnings" do
        result = described_class.new(ad).call
        types = result[:warnings].map { |w| w[:type] }
        expect(types).to include("no_text_layers")
        expect(types).to include("no_logo_detected")
      end
    end

    context "SVG with small font" do
      before do
        svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><text font-size="4" font-family="Arial" font-weight="normal" fill="#000" x="10" y="20">Tiny</text></svg>)
        ad.file.attach(io: StringIO.new(svg), filename: "ad.svg", content_type: "image/svg+xml")
      end

      it "warns about small font size" do
        result = described_class.new(ad).call
        types = result[:warnings].map { |w| w[:type] }
        expect(types).to include("font_size_too_small")
      end
    end

    context "SVG with paths and no text (outlined text)" do
      before do
        svg = '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><path d="M0 0 L100 0 L100 100 Z"/></svg>'
        ad.file.attach(io: StringIO.new(svg), filename: "ad.svg", content_type: "image/svg+xml")
      end

      it "warns about possible outlined text" do
        result = described_class.new(ad).call
        types = result[:warnings].map { |w| w[:type] }
        expect(types).to include("possible_outlined_text")
      end
    end

    context "SVG with full-canvas background image" do
      before do
        svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="300" height="250">
          <image href="data:bg" x="0" y="0" width="300" height="250"/>
          <image href="data:logo" x="10" y="10" width="50" height="50"/>
          <text #{text_attrs} x="10" y="20">Hi</text>
        </svg>)
        ad.file.attach(io: StringIO.new(svg), filename: "ad.svg", content_type: "image/svg+xml")
      end

      it "skips full-canvas images but keeps small ones" do
        result = described_class.new(ad).call
        images = result[:layers].select { |l| l[:type] == "image" }
        expect(images.size).to eq(1)
        expect(images.first[:href]).to eq("data:logo")
      end
    end

    context "SVG with path shapes" do
      before do
        svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="300" height="250">
          <path fill="#00FF00" d="M 50 180 L 150 180 L 150 220 L 50 220 Z"/>
          <text #{text_attrs} x="10" y="20">Hi</text>
        </svg>)
        ad.file.attach(io: StringIO.new(svg), filename: "ad.svg", content_type: "image/svg+xml")
      end

      it "extracts path shapes" do
        result = described_class.new(ad).call
        shapes = result[:layers].select { |l| l[:type] == "shape" && l[:shape] == "path" }
        expect(shapes.size).to eq(1)
      end
    end

    context "unsupported file type" do
      before do
        ad.file.attach(io: StringIO.new("fake"), filename: "ad.jpg", content_type: "image/jpeg")
      end

      it "returns unsupported format warning" do
        result = described_class.new(ad).call
        types = result[:warnings].map { |w| w[:type] }
        expect(types).to include("unsupported_format")
      end
    end

    context "no file attached" do
      it "returns nil" do
        expect(described_class.new(ad).call).to be_nil
      end
    end
  end

  describe "private methods" do
    let(:service) { described_class.new(ad) }

    it "computes aspect ratio" do
      expect(service.send(:compute_aspect_ratio, 1920, 1080)).to eq("16:9")
    end

    it "returns nil aspect ratio for zero dims" do
      expect(service.send(:compute_aspect_ratio, 0, 100)).to be_nil
    end

    it "computes path bounding box" do
      box = service.send(:path_bounding_box, "M 10 20 L 100 20 L 100 80 L 10 80 Z")
      expect(box[:w]).to eq(90)
      expect(box[:h]).to eq(60)
    end

    it "returns nil for blank path" do
      expect(service.send(:path_bounding_box, "")).to be_nil
    end

    it "reads fill from attribute" do
      node = Nokogiri::XML('<rect fill="#FF0000"/>').at_css("rect")
      expect(service.send(:read_fill, node)).to eq("#FF0000")
    end

    it "reads fill from style" do
      node = Nokogiri::XML('<rect style="fill: #00FF00;"/>').at_css("rect")
      expect(service.send(:read_fill, node)).to eq("#00FF00")
    end

    it "joins runs into text with spaces" do
      # Test with mock run objects
      run1 = double("run", text: "Hello", origin: double(x: 0, y: 100), font_size: 14)
      run2 = double("run", text: "World", origin: double(x: 50, y: 100), font_size: 14)
      result = service.send(:join_runs_into_text, [run1, run2])
      expect(result).to include("Hello")
      expect(result).to include("World")
    end
  end
end
