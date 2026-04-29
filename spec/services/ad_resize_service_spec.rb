require 'rails_helper'

RSpec.describe AdResizeService do
  include_context "seeded ad platforms"

  let(:ad) do
    create(:ad,
      width: 1080,
      height: 1350,
      parsed_layers: [
        { "id" => "text_1", "type" => "text", "content" => "Hello World", "x" => "100", "y" => "200", "width" => "400", "height" => "100", "font_size" => "48" },
        { "id" => "text_2", "type" => "text", "content" => "Buy Now", "x" => "100", "y" => "600", "width" => "400", "height" => "80", "font_size" => "36" }
      ]
    )
  end

  before do
    # Stub file attachment for SVG generation
    svg_blob = double("blob", download: '<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1350" viewBox="0 0 1080 1350"><text>Hello</text></svg>')
    svg_attachment = double("attachment", attached?: true, blob: svg_blob)
    converted_attachment = double("attachment", attached?: false)
    allow(ad).to receive(:file).and_return(svg_attachment)
    allow(ad).to receive(:file_content_type).and_return("image/svg+xml")
    allow(ad).to receive(:converted_svg).and_return(converted_attachment)

    # Stub Vips to avoid actual image processing in unit tests
    vips_image = double("vips_image")
    allow(Vips::Image).to receive(:new_from_buffer).and_return(vips_image)
    allow(vips_image).to receive(:pngsave_buffer).and_return("fake_png_binary")
    allow(vips_image).to receive(:jpegsave_buffer).and_return("fake_jpg_binary")
  end

  describe "#call" do
    it "creates ad_resizes for selected platforms" do
      service = described_class.new(ad, platforms: [ "Facebook (Meta)" ])
      resizes = service.call

      expect(resizes.length).to eq(3) # Feed Image, Story, Landscape
      expect(ad.ad_resizes.count).to eq(3)
    end

    it "deduplicates sizes across platforms" do
      service = described_class.new(ad, platforms: [ "Facebook (Meta)", "Instagram" ])
      resizes = service.call

      # Both have 1080x1080 and 1080x1920, but should only create one each
      dims = resizes.map { |r| "#{r.width}x#{r.height}" }
      expect(dims.count("1080x1080")).to eq(1)
      expect(dims.count("1080x1920")).to eq(1)
    end

    it "scales layer positions proportionally" do
      service = described_class.new(ad, platforms: [ "Reddit" ]) # 1200x628
      resizes = service.call
      resize = resizes.first

      # scale_x = 1200/1080 ≈ 1.111, scale_y = 628/1350 ≈ 0.465
      text_1 = resize.resized_layers.find { |l| l["id"] == "text_1" }
      expect(text_1["x"].to_i).to eq((100 * 1200.0 / 1080).round)
      expect(text_1["y"].to_i).to eq((200 * 628.0 / 1350).round)
    end

    it "scales font size using minimum scale factor" do
      service = described_class.new(ad, platforms: [ "Reddit" ]) # 1200x628
      resizes = service.call
      resize = resizes.first

      # min(1200/1080, 628/1350) ≈ 0.465
      text_1 = resize.resized_layers.find { |l| l["id"] == "text_1" }
      expected_size = [ 48 * [ 1200.0 / 1080, 628.0 / 1350 ].min, 8 ].max.round
      expect(text_1["font_size"].to_i).to eq(expected_size)
    end

    it "clamps font size to minimum 8" do
      ad.update!(parsed_layers: [
        { "id" => "text_tiny", "type" => "text", "content" => "Tiny", "x" => "10", "y" => "10", "font_size" => "10" }
      ])

      # Google Leaderboard: 728x90. scale_y = 90/1350 ≈ 0.067
      service = described_class.new(ad, platforms: [ "Google Display" ])
      resizes = service.call
      leaderboard = resizes.find { |r| r.width == 728 && r.height == 90 }
      text = leaderboard.resized_layers.find { |l| l["id"] == "text_tiny" }
      expect(text["font_size"].to_i).to be >= 8
    end

    it "computes aspect ratio" do
      service = described_class.new(ad, platforms: [ "Facebook (Meta)" ])
      resizes = service.call

      square = resizes.find { |r| r.width == 1080 && r.height == 1080 }
      expect(square.aspect_ratio).to eq("1:1")

      story = resizes.find { |r| r.width == 1080 && r.height == 1920 }
      expect(story.aspect_ratio).to eq("9:16")
    end

    it "sets state to resized on success" do
      service = described_class.new(ad, platforms: [ "Threads" ])
      resizes = service.call
      expect(resizes.first.state).to eq("resized")
    end

    it "destroys existing resizes before creating new ones" do
      create(:ad_resize, ad: ad, width: 999, height: 999, platform_labels: [ { "platform" => "Test", "size_name" => "Old" } ])
      expect(ad.ad_resizes.count).to eq(1)

      service = described_class.new(ad, platforms: [ "Threads" ])
      service.call

      ad.reload
      expect(ad.ad_resizes.count).to eq(1)
      expect(ad.ad_resizes.first.width).to eq(1080)
    end

    it "raises error when ad has no dimensions" do
      ad.update_columns(width: nil, height: nil)
      service = described_class.new(ad, platforms: [ "Facebook (Meta)" ])
      expect { service.call }.to raise_error(AdResizeService::Error, /no dimensions/i)
    end

    it "raises error when ad has no parsed layers" do
      ad.update_columns(parsed_layers: [])
      service = described_class.new(ad, platforms: [ "Facebook (Meta)" ])
      expect { service.call }.to raise_error(AdResizeService::Error, /no parsed layers/i)
    end

    it "raises error for invalid platforms" do
      service = described_class.new(ad, platforms: [ "NonExistentPlatform" ])
      expect { service.call }.to raise_error(AdResizeService::Error, /no valid sizes/i)
    end

    it "stores platform labels with deduplication" do
      service = described_class.new(ad, platforms: [ "Facebook (Meta)", "Instagram", "LinkedIn" ])
      resizes = service.call

      square = resizes.find { |r| r.width == 1080 && r.height == 1080 }
      platforms = square.platform_labels.map { |l| l["platform"] }
      expect(platforms).to include("Facebook (Meta)", "Instagram", "LinkedIn")
    end
  end

  describe ".rebuild" do
    it "destroys and recreates a resize" do
      service = described_class.new(ad, platforms: ["Threads"])
      resizes = service.call
      original = resizes.first
      original_id = original.id

      new_resize = described_class.rebuild(original)
      expect(new_resize).to be_persisted
      expect(new_resize.id).not_to eq(original_id)
      expect(new_resize.width).to eq(original.width)
      expect(new_resize.height).to eq(original.height)
    end
  end

  describe "private methods" do
    let(:service) { described_class.new(ad, platforms: []) }

    describe "#fallback_svg" do
      it "generates a placeholder SVG" do
        svg = service.send(:fallback_svg, 728, 90)
        expect(svg).to include("<svg")
        expect(svg).to include("728x90")
      end
    end

    describe "#rescale_svg" do
      it "updates width, height, and viewBox" do
        source = '<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1080"><text>Hi</text></svg>'
        result = service.send(:rescale_svg, source, 300, 250)
        doc = Nokogiri::XML(result)
        root = doc.at_css("svg")
        expect(root["width"]).to eq("300")
        expect(root["height"]).to eq("250")
        expect(root["viewBox"]).to include("1080")
      end
    end

    describe "#compute_aspect_ratio" do
      it "simplifies ratios" do
        expect(service.send(:compute_aspect_ratio, 1920, 1080)).to eq("16:9")
      end

      it "returns nil for zero" do
        expect(service.send(:compute_aspect_ratio, 0, 100)).to be_nil
      end
    end
  end
end
