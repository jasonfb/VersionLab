require 'rails_helper'

RSpec.describe AdVersion, type: :model do
  describe "associations" do
    it "belongs to ad" do
      assoc = described_class.reflect_on_association(:ad)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to audience" do
      assoc = described_class.reflect_on_association(:audience)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to ai_service" do
      assoc = described_class.reflect_on_association(:ai_service)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to ai_model" do
      assoc = described_class.reflect_on_association(:ai_model)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to ad_resize (optional)" do
      assoc = described_class.reflect_on_association(:ad_resize)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to eq(true)
    end
  end

  describe "validations" do
    it "requires a version_number" do
      ad_version = build(:ad_version, version_number: nil)
      expect(ad_version).not_to be_valid
      expect(ad_version.errors[:version_number]).to include("can't be blank")
    end
  end

  describe "enums" do
    it "defines state enum" do
      expect(described_class.states).to eq(
        "generating" => "generating", "active" => "active", "rejected" => "rejected"
      )
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active ad versions" do
        active_version = create(:ad_version, state: :active)
        generating_version = create(:ad_version, state: :generating)
        rejected_version = create(:ad_version, state: :rejected)

        expect(described_class.active).to include(active_version)
        expect(described_class.active).not_to include(generating_version, rejected_version)
      end
    end
  end
end
