require 'rails_helper'

RSpec.describe AdParseService, type: :service do
  let(:client) { create(:client) }

  def build_ad_with_pdf(filename)
    ad = create(:ad, client: client, name: filename)
    path = Rails.root.join("spec/fixtures/files/#{filename}")
    ad.file.attach(
      io: File.open(path),
      filename: filename,
      content_type: "application/pdf"
    )
    ad
  end

  shared_examples "a parsed PDF ad" do |filename, expected_min_layers:|
    let(:ad) { build_ad_with_pdf(filename) }

    before { described_class.new(ad).call; ad.reload }

    it "converts to SVG and attaches converted_svg" do
      expect(ad.converted_svg).to be_attached
      expect(ad.converted_svg.content_type).to eq("image/svg+xml")
    end

    it "extracts dimensions" do
      expect(ad.width).to be > 0
      expect(ad.height).to be > 0
    end

    it "computes an aspect ratio" do
      expect(ad.aspect_ratio).to be_present
      expect(ad.aspect_ratio).to match(/\A\d+:\d+\z/)
    end

    it "extracts at least #{expected_min_layers} text region layers" do
      text_layers = ad.parsed_layers.select { |l| l["type"] == "text" }
      expect(text_layers.length).to be >= expected_min_layers
    end

    it "includes bounding box data (x, y, width, height) on each layer" do
      ad.parsed_layers.each do |layer|
        expect(layer["x"]).to be_present, "layer #{layer['id']} missing x"
        expect(layer["y"]).to be_present, "layer #{layer['id']} missing y"
        expect(layer["width"]).to be_present, "layer #{layer['id']} missing width"
        expect(layer["height"]).to be_present, "layer #{layer['id']} missing height"
      end
    end

    it "generates region IDs in sequence" do
      ids = ad.parsed_layers.map { |l| l["id"] }
      ids.each_with_index do |id, i|
        expect(id).to eq("region_#{i}")
      end
    end
  end

  describe "PDF conversion and parsing" do
    context "with 1_SolidBkg_StaticType.pdf (1080x1080 solid background, static text)" do
      it_behaves_like "a parsed PDF ad", "1_SolidBkg_StaticType.pdf", expected_min_layers: 4
    end

    context "with 1_SolidBkg_VariableType.pdf (1080x1080 solid background, variable text)" do
      it_behaves_like "a parsed PDF ad", "1_SolidBkg_VariableType.pdf", expected_min_layers: 4
    end

    context "with 3_FB_1080x1080_PhotoBkg.pdf (1080x1080 photo background)" do
      it_behaves_like "a parsed PDF ad", "3_FB_1080x1080_PhotoBkg.pdf", expected_min_layers: 3
    end

    context "with 5_FB_1080x1350_SolidBkg.pdf (1080x1350 solid background)" do
      it_behaves_like "a parsed PDF ad", "5_FB_1080x1350_SolidBkg.pdf", expected_min_layers: 3
    end
  end

  describe "dimension extraction" do
    it "extracts 1080x1080 for square PDFs" do
      ad = build_ad_with_pdf("1_SolidBkg_StaticType.pdf")
      described_class.new(ad).call
      ad.reload
      expect(ad.width).to eq(1080)
      expect(ad.height).to eq(1080)
      expect(ad.aspect_ratio).to eq("1:1")
    end

    it "extracts correct dimensions for 5_FB_1080x1350_SolidBkg.pdf" do
      ad = build_ad_with_pdf("5_FB_1080x1350_SolidBkg.pdf")
      described_class.new(ad).call
      ad.reload
      # MediaBox is actually 1080x1080 despite the filename
      expect(ad.width).to eq(1080)
      expect(ad.height).to eq(1080)
    end
  end

  describe "idempotent re-parsing" do
    it "replaces previous converted_svg on re-parse" do
      ad = build_ad_with_pdf("1_SolidBkg_StaticType.pdf")
      described_class.new(ad).call
      first_blob_id = ad.converted_svg.blob.id

      described_class.new(ad).call
      ad.reload
      expect(ad.converted_svg).to be_attached
      expect(ad.converted_svg.blob.id).not_to eq(first_blob_id)
    end
  end
end
