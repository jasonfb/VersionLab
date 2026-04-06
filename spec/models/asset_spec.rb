# == Schema Information
#
# Table name: assets
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  folder             :string
#  height             :integer
#  name               :string
#  standardized_ratio :enum
#  width              :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  client_id          :uuid             not null
#
# Indexes
#
#  index_assets_on_client_id  (client_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_id => clients.id)
#
require 'rails_helper'

RSpec.describe Asset, type: :model do
  describe "associations" do
    it "belongs to client" do
      assoc = described_class.reflect_on_association(:client)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "STANDARD_RATIOS" do
    it "defines five standard aspect ratios" do
      expect(described_class::STANDARD_RATIOS.length).to eq(5)
    end

    it "includes expected ratio keys" do
      keys = described_class::STANDARD_RATIOS.map { |r| r[:key] }
      expect(keys).to eq(%w[hero_3_1 banner_2_1 widescreen_16_9 square_1_1 portrait_4_5])
    end

    it "is frozen" do
      expect(described_class::STANDARD_RATIOS).to be_frozen
    end
  end

  describe ".snap_to_standard_ratio" do
    it "returns nil when width is nil" do
      expect(described_class.snap_to_standard_ratio(nil, 100)).to be_nil
    end

    it "returns nil when height is nil" do
      expect(described_class.snap_to_standard_ratio(100, nil)).to be_nil
    end

    it "returns nil when height is zero" do
      expect(described_class.snap_to_standard_ratio(100, 0)).to be_nil
    end

    it "snaps 1:1 to square_1_1" do
      expect(described_class.snap_to_standard_ratio(500, 500)).to eq("square_1_1")
    end

    it "snaps 3:1 to hero_3_1" do
      expect(described_class.snap_to_standard_ratio(900, 300)).to eq("hero_3_1")
    end

    it "snaps 2:1 to banner_2_1" do
      expect(described_class.snap_to_standard_ratio(800, 400)).to eq("banner_2_1")
    end

    it "snaps 16:9 to widescreen_16_9" do
      expect(described_class.snap_to_standard_ratio(1920, 1080)).to eq("widescreen_16_9")
    end

    it "snaps 4:5 to portrait_4_5" do
      expect(described_class.snap_to_standard_ratio(400, 500)).to eq("portrait_4_5")
    end

    it "snaps a close-to-square ratio to square_1_1" do
      expect(described_class.snap_to_standard_ratio(510, 500)).to eq("square_1_1")
    end

    it "snaps a wide ratio closer to 3:1 than 2:1 to hero_3_1" do
      expect(described_class.snap_to_standard_ratio(2800, 1000)).to eq("hero_3_1")
    end
  end

  describe "#file_url" do
    it "returns nil when no file is attached" do
      asset = build(:asset)
      allow(asset).to receive(:file).and_return(double(attached?: false))
      expect(asset.file_url).to be_nil
    end
  end
end
