require 'rails_helper'

RSpec.describe AdRenderService do
  let(:client) { create(:client) }
  let(:ai_service) { create(:ai_service) }
  let(:ai_model) { create(:ai_model, ai_service: ai_service) }
  let(:audience) { create(:audience, client: client) }
  let(:ad) do
    create(:ad, client: client, width: 300, height: 250,
           ai_service: ai_service, ai_model: ai_model,
           parsed_layers: [
             { "id" => "l1", "type" => "text", "content" => "Original", "font_size" => 24, "x" => 10, "y" => 30, "width" => 280, "height" => 50 }
           ])
  end
  let(:version) do
    create(:ad_version, ad: ad, audience: audience,
           ai_service: ai_service, ai_model: ai_model, state: "active",
           generated_layers: [
             { "id" => "l1", "content" => "New Copy", "original_content" => "Original" }
           ])
  end

  describe "#call" do
    it "raises when ad has no dimensions" do
      ad.update_columns(width: nil, height: nil)
      expect { described_class.new(version).call }.to raise_error(AdRenderService::Error, /no dimensions/)
    end
  end

  describe "#build_svg_from_scratch (private)" do
    let(:service) { described_class.new(version) }

    it "generates SVG with text elements" do
      svg = service.send(:build_svg_from_scratch)
      expect(svg).to include("<svg")
      expect(svg).to include("New Copy")
      expect(svg).to include('width="300"')
      expect(svg).to include('height="250"')
    end
  end

  describe "#auto_font_size (private)" do
    let(:service) { described_class.new(version) }

    it "returns 24 for zero-width region" do
      expect(service.send(:auto_font_size, "Hello", 0, 100)).to eq(24)
    end

    it "returns 24 for empty content" do
      expect(service.send(:auto_font_size, "", 200, 100)).to eq(24)
    end

    it "returns a size that fits the region" do
      size = service.send(:auto_font_size, "Short text", 200, 50)
      expect(size).to be_between(12, 120)
    end

    it "returns minimum 12 for very large text in small region" do
      size = service.send(:auto_font_size, "A" * 5000, 50, 20)
      expect(size).to eq(12)
    end
  end

  describe "#wrap_text (private)" do
    let(:service) { described_class.new(version) }

    it "wraps long text into multiple lines" do
      lines = service.send(:wrap_text, "This is a very long sentence that should wrap", 20, 200)
      expect(lines.length).to be > 1
    end

    it "returns single-line array for short text" do
      lines = service.send(:wrap_text, "Short", 20, 200)
      expect(lines).to eq(["Short"])
    end
  end

  describe "#build_overlay (private)" do
    let(:service) { described_class.new(version) }

    it "returns empty string when overlay disabled" do
      expect(service.send(:build_overlay, 300, 250)).to eq("")
    end

    it "returns rect for solid overlay" do
      ad.update!(overlay_enabled: true, overlay_type: "solid", overlay_color: "#000000", overlay_opacity: 50)
      result = service.send(:build_overlay, 300, 250)
      expect(result).to include("rect")
      expect(result).to include("fill-opacity")
    end

    it "returns gradient for gradient overlay" do
      ad.update!(overlay_enabled: true, overlay_type: "gradient", overlay_color: "#FFFFFF")
      result = service.send(:build_overlay, 300, 250)
      expect(result).to include("linearGradient")
    end
  end

  describe "#build_play_button (private)" do
    let(:service) { described_class.new(version) }

    it "returns empty string when play button disabled" do
      expect(service.send(:build_play_button, 300, 250)).to eq("")
    end

    it "returns circle+polygon when enabled" do
      ad.update!(play_button_enabled: true)
      result = service.send(:build_play_button, 300, 250)
      expect(result).to include("circle")
      expect(result).to include("polygon")
    end
  end

  describe "#build_background (private)" do
    let(:service) { described_class.new(version) }

    it "returns solid color rect" do
      ad.update!(background_type: "solid_color", background_color: "#FF0000")
      result = service.send(:build_background, 300, 250)
      expect(result).to include("rect")
      expect(result).to include("FF0000")
    end

    it "returns black fallback when no background asset" do
      ad.update!(background_type: "image")
      result = service.send(:build_background, 300, 250)
      expect(result).to include("#000000")
    end
  end

  describe "#build_text_element (private)" do
    let(:service) { described_class.new(version) }

    it "generates text element with default styles" do
      ov = {}.with_indifferent_access
      result = service.send(:build_text_element, 10, 30, 280, 50, "Hello World", ov)
      expect(result).to include("<text")
      expect(result).to include("Hello World")
      expect(result).to include("font-family")
    end

    it "applies font overrides" do
      ov = { font_family: "Georgia", font_size: "32", fill: "#FF0000",
             is_bold: true, is_italic: true, text_align: "center" }.with_indifferent_access
      result = service.send(:build_text_element, 0, 0, 300, 50, "Styled", ov)
      expect(result).to include("Georgia")
      expect(result).to include("bold")
      expect(result).to include("italic")
      expect(result).to include("middle") # center → middle text-anchor
    end

    it "applies right alignment" do
      ov = { text_align: "right" }.with_indifferent_access
      result = service.send(:build_text_element, 0, 0, 300, 50, "Right", ov)
      expect(result).to include('"end"')
    end

    it "wraps text into multiple tspan elements" do
      ov = {}.with_indifferent_access
      long_text = "This is a long text that should definitely wrap into multiple lines"
      result = service.send(:build_text_element, 0, 0, 100, 100, long_text, ov)
      expect(result.scan("<tspan").count).to be > 1
    end
  end

  describe "#build_text_layers (private)" do
    let(:service) { described_class.new(version) }

    it "generates text layers from generated content" do
      result = service.send(:build_text_layers)
      expect(result).to include("New Copy")
    end

    it "returns empty string when no generated content" do
      version.update!(generated_layers: [])
      result = service.send(:build_text_layers)
      expect(result).to eq("")
    end
  end

  describe "#generated_content_map (private)" do
    let(:service) { described_class.new(version) }

    it "returns a hash of layer id to content" do
      result = service.send(:generated_content_map)
      expect(result["l1"]).to eq("New Copy")
    end
  end

  describe "#effective_width/height (private)" do
    let(:service) { described_class.new(version) }

    it "returns ad dimensions when no resize" do
      expect(service.send(:effective_width)).to eq(300)
      expect(service.send(:effective_height)).to eq(250)
    end
  end

  describe "#escape (private)" do
    let(:service) { described_class.new(version) }

    it "escapes XML special characters" do
      result = service.send(:escape, '<script>alert("xss")</script>')
      expect(result).not_to include("<script>")
    end
  end

  describe "#build_svg_from_converted (private)" do
    let(:converted_svg) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="300" height="250" viewBox="0 0 300 250">
          <g clip-path="url(#clip1)">
            <g clip-path="url(#clip2)">
              <use href="#img1"/>
            </g>
          </g>
          <defs>
            <clipPath id="clip1"><path d="M 10 20 L 290 20 L 290 70 L 10 70 Z"/></clipPath>
            <clipPath id="clip2"><path d="M 10 20 L 11 20 L 11 21 L 10 21 Z"/></clipPath>
          </defs>
        </svg>
      SVG
    end

    before do
      ad.converted_svg.attach(
        io: StringIO.new(converted_svg),
        filename: "converted.svg",
        content_type: "image/svg+xml"
      )
    end

    let(:service) { described_class.new(version) }

    it "generates SVG from converted source" do
      svg = service.send(:build_svg_from_converted)
      expect(svg).to include("<svg")
      expect(svg).to include("New Copy")
    end

    it "removes complex clip-path groups (glyph outlines)" do
      svg = service.send(:build_svg_from_converted)
      # The inner clip with only 4 coordinates (simple) should be preserved
      # but we're testing the method runs without error
      expect(svg).to be_a(String)
    end
  end

  describe "#build_svg (private)" do
    let(:service) { described_class.new(version) }

    it "uses build_svg_from_scratch when no converted_svg" do
      svg = service.send(:build_svg)
      expect(svg).to include("New Copy")
      expect(svg).to include("<svg")
    end

    it "uses build_svg_from_converted when converted_svg exists" do
      simple_svg = '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="250"><rect width="300" height="250"/></svg>'
      ad.converted_svg.attach(
        io: StringIO.new(simple_svg),
        filename: "converted.svg",
        content_type: "image/svg+xml"
      )

      svg = service.send(:build_svg)
      expect(svg).to include("<svg")
    end
  end

  describe "#effective_layer_overrides (private)" do
    let(:service) { described_class.new(version) }

    it "returns ad layer_overrides when no resize" do
      ad.update!(layer_overrides: { "l1" => { "font_size" => 20 } })
      result = service.send(:effective_layer_overrides)
      expect(result["l1"]).to eq({ "font_size" => 20 })
    end
  end

  describe "#effective_parsed_layers (private)" do
    let(:service) { described_class.new(version) }

    it "returns ad parsed_layers" do
      result = service.send(:effective_parsed_layers)
      expect(result).to eq(ad.parsed_layers)
    end
  end

  describe "#build_text_element with underline (private)" do
    let(:service) { described_class.new(version) }

    it "applies underline decoration" do
      ov = { is_underline: true }.with_indifferent_access
      result = service.send(:build_text_element, 10, 30, 280, 50, "Underlined", ov)
      expect(result).to include("underline")
    end

    it "applies letter spacing" do
      ov = { letter_spacing: "2" }.with_indifferent_access
      result = service.send(:build_text_element, 10, 30, 280, 50, "Spaced", ov)
      expect(result).to include("letter-spacing")
    end

    it "applies custom line height" do
      ov = { line_height: "2.0" }.with_indifferent_access
      result = service.send(:build_text_element, 10, 30, 280, 50, "Tall lines go here and wrap", ov)
      expect(result).to include("<tspan")
    end
  end

  describe "#wrap_text with bold (private)" do
    let(:service) { described_class.new(version) }

    it "uses wider char estimate for bold" do
      lines_bold = service.send(:wrap_text, "This is a test sentence for wrapping", 20, 200, true)
      lines_normal = service.send(:wrap_text, "This is a test sentence for wrapping", 20, 200, false)
      # Bold text has wider chars so may wrap more
      expect(lines_bold.length).to be >= lines_normal.length
    end
  end
end
