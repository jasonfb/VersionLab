# == Schema Information
#
# Table name: ads
# Database name: primary
#
#  id                        :uuid             not null, primary key
#  aspect_ratio              :string
#  background_color          :string           default("#000000")
#  background_type           :enum             default("solid_color")
#  classifications_confirmed :boolean          default(FALSE), not null
#  classified_layers         :jsonb            not null
#  file_warnings             :jsonb
#  height                    :integer
#  keep_background           :boolean          default(TRUE), not null
#  layer_overrides           :jsonb
#  name                      :string           not null
#  nlp_prompt                :text
#  output_format             :enum             default("png")
#  overlay_color             :string           default("#FFFFFF")
#  overlay_enabled           :boolean          default(FALSE), not null
#  overlay_opacity           :integer          default(80)
#  overlay_type              :enum             default("solid")
#  parsed_layers             :jsonb
#  play_button_color         :string           default("#FFFFFF")
#  play_button_enabled       :boolean          default(FALSE), not null
#  play_button_style         :string           default("circle_filled")
#  state                     :enum             default("setup"), not null
#  versioning_mode           :enum             default("retain_existing")
#  width                     :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  ai_model_id               :uuid
#  ai_service_id             :uuid
#  background_asset_id       :uuid
#  campaign_id               :uuid
#  client_id                 :uuid             not null
#
# Indexes
#
#  index_ads_on_client_id  (client_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_id => clients.id)
#
require 'rails_helper'

RSpec.describe Ad, type: :model do
  describe "associations" do
    it "belongs to client" do
      assoc = described_class.reflect_on_association(:client)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to campaign (optional)" do
      assoc = described_class.reflect_on_association(:campaign)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to eq(true)
    end

    it "belongs to ai_service (optional)" do
      assoc = described_class.reflect_on_association(:ai_service)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to eq(true)
    end

    it "belongs to ai_model (optional)" do
      assoc = described_class.reflect_on_association(:ai_model)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to eq(true)
    end

    it "belongs to background_asset as Asset (optional)" do
      assoc = described_class.reflect_on_association(:background_asset)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:class_name]).to eq("Asset")
      expect(assoc.options[:optional]).to eq(true)
    end

    it "has many ad_audiences with dependent destroy" do
      assoc = described_class.reflect_on_association(:ad_audiences)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many audiences through ad_audiences" do
      assoc = described_class.reflect_on_association(:audiences)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:ad_audiences)
    end

    it "has many ad_versions with dependent destroy" do
      assoc = described_class.reflect_on_association(:ad_versions)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many ad_resizes with dependent destroy" do
      assoc = described_class.reflect_on_association(:ad_resizes)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end
  end

  describe "validations" do
    it "requires a name" do
      ad = build(:ad, name: nil)
      expect(ad).not_to be_valid
      expect(ad.errors[:name]).to include("can't be blank")
    end

    it "is valid with a name" do
      ad = build(:ad)
      expect(ad).to be_valid
    end
  end

  describe "enums" do
    it "defines state enum" do
      expect(described_class.states).to eq(
        "setup" => "setup", "resizing" => "resizing", "pending" => "pending", "merged" => "merged", "regenerating" => "regenerating"
      )
    end

    it "defines background_type enum" do
      expect(described_class.background_types).to eq(
        "solid_color" => "solid_color", "image" => "image"
      )
    end

    it "defines overlay_type enum" do
      expect(described_class.overlay_types).to eq(
        "solid" => "solid", "gradient" => "gradient"
      )
    end

    it "defines versioning_mode enum" do
      expect(described_class.versioning_modes).to eq(
        "retain_existing" => "retain_existing", "version_ads" => "version_ads"
      )
    end

    it "defines output_format enum" do
      expect(described_class.output_formats).to eq(
        "png" => "png", "jpg" => "jpg"
      )
    end
  end

  describe "#file_url" do
    it "returns nil when no file is attached" do
      ad = build(:ad)
      allow(ad).to receive(:file).and_return(double(attached?: false))
      expect(ad.file_url).to be_nil
    end
  end

  describe "#file_content_type" do
    it "returns nil when no file is attached" do
      ad = build(:ad)
      allow(ad).to receive(:file).and_return(double(attached?: false))
      expect(ad.file_content_type).to be_nil
    end
  end

  describe "#svg_url" do
    it "returns nil when nothing is attached" do
      ad = build(:ad)
      allow(ad).to receive(:converted_svg).and_return(double(attached?: false))
      allow(ad).to receive(:file).and_return(double(attached?: false))
      expect(ad.svg_url).to be_nil
    end
  end
end
