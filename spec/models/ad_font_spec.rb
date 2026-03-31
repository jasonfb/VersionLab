require "rails_helper"

RSpec.describe AdFont do
  let(:ad) { create(:ad) }
  let(:font_data) { File.read(Rails.root.join("spec/fixtures/files/roboto-bold-subset.ttf"), mode: "rb") }
  let(:ad_font) do
    font = ad.ad_fonts.create!(font_name: "Roboto-Bold", postscript_name: "YLXZXL+Roboto-Bold")
    font.font_file.attach(
      io: StringIO.new(font_data),
      filename: "roboto-bold-subset.ttf",
      content_type: "font/ttf"
    )
    font
  end

  describe "validations" do
    it "requires font_name" do
      font = AdFont.new(ad: ad, font_name: nil)
      expect(font).not_to be_valid
      expect(font.errors[:font_name]).to be_present
    end
  end

  describe "#measure_text_width" do
    it "returns a positive width for known characters" do
      width = ad_font.measure_text_width("Hello", 24)
      expect(width).to be_a(Numeric)
      expect(width).to be > 0
    end

    it "scales proportionally with font size" do
      width_12 = ad_font.measure_text_width("Test", 12)
      width_24 = ad_font.measure_text_width("Test", 24)
      expect(width_24).to be_within(0.1).of(width_12 * 2)
    end

    it "returns wider values for longer strings" do
      short = ad_font.measure_text_width("Hi", 24)
      long = ad_font.measure_text_width("Hello World", 24)
      expect(long).to be > short
    end

    it "returns nil when no font file is attached" do
      bare_font = ad.ad_fonts.create!(font_name: "Missing")
      expect(bare_font.measure_text_width("Test", 24)).to be_nil
    end
  end

  describe "#word_wrap" do
    it "returns a single line when text fits within max_width" do
      # Measure the full text first to find a generous max_width
      full_width = ad_font.measure_text_width("Short text", 24)
      lines = ad_font.word_wrap("Short text", 24, full_width + 10)
      expect(lines).to eq(["Short text"])
    end

    it "wraps text into multiple lines when it exceeds max_width" do
      text = "This is a longer sentence that should wrap"
      # Use a narrow width to force wrapping
      lines = ad_font.word_wrap(text, 24, 100)
      expect(lines.length).to be > 1
      expect(lines.join(" ")).to eq(text)
    end

    it "returns single-element array for single-word text" do
      lines = ad_font.word_wrap("Hello", 24, 50)
      expect(lines).to eq(["Hello"])
    end

    it "preserves all words across wrapped lines" do
      text = "One two three four five"
      lines = ad_font.word_wrap(text, 24, 80)
      expect(lines.join(" ")).to eq(text)
    end
  end
end
