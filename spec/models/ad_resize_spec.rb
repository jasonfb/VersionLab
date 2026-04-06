# == Schema Information
#
# Table name: ad_resizes
# Database name: primary
#
#  id              :uuid             not null, primary key
#  aspect_ratio    :string
#  height          :integer          not null
#  layer_overrides :jsonb
#  platform_labels :jsonb            not null
#  resized_layers  :jsonb
#  state           :enum             default("pending"), not null
#  width           :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  ad_id           :uuid             not null
#
# Indexes
#
#  index_ad_resizes_on_ad_id                       (ad_id)
#  index_ad_resizes_on_ad_id_and_width_and_height  (ad_id,width,height) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ad_id => ads.id)
#
require 'rails_helper'

RSpec.describe AdResize, type: :model do
  describe "associations" do
    it "belongs to ad" do
      assoc = described_class.reflect_on_association(:ad)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "has many ad_versions with dependent nullify" do
      assoc = described_class.reflect_on_association(:ad_versions)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:nullify)
    end
  end

  describe "validations" do
    it "requires width" do
      resize = build(:ad_resize, width: nil)
      expect(resize).not_to be_valid
      expect(resize.errors[:width]).to include("can't be blank")
    end

    it "requires height" do
      resize = build(:ad_resize, height: nil)
      expect(resize).not_to be_valid
      expect(resize.errors[:height]).to include("can't be blank")
    end

    it "requires positive width" do
      resize = build(:ad_resize, width: 0)
      expect(resize).not_to be_valid
    end

    it "requires positive height" do
      resize = build(:ad_resize, height: 0)
      expect(resize).not_to be_valid
    end

    it "requires platform_labels" do
      resize = build(:ad_resize, platform_labels: [])
      expect(resize).not_to be_valid
    end

    it "is valid with proper attributes" do
      resize = build(:ad_resize)
      expect(resize).to be_valid
    end
  end

  describe "enums" do
    it "defines state enum" do
      expect(described_class.states).to eq(
        "pending" => "pending", "resized" => "resized", "failed" => "failed"
      )
    end
  end

  describe "#label" do
    it "joins platform labels" do
      resize = build(:ad_resize, platform_labels: [
        { "platform" => "Facebook (Meta)", "size_name" => "Feed Image" },
        { "platform" => "Instagram", "size_name" => "Feed Square" }
      ])
      expect(resize.label).to eq("Facebook (Meta) Feed Image, Instagram Feed Square")
    end
  end

  describe "#dimensions" do
    it "returns widthxheight string" do
      resize = build(:ad_resize, width: 1080, height: 1920)
      expect(resize.dimensions).to eq("1080x1920")
    end
  end
end
