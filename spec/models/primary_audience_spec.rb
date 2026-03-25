require 'rails_helper'

RSpec.describe PrimaryAudience, type: :model do
  describe "associations" do
    it "has many brand_profile_primary_audiences" do
      assoc = described_class.reflect_on_association(:brand_profile_primary_audiences)
      expect(assoc.macro).to eq(:has_many)
    end

    it "has many brand_profiles through brand_profile_primary_audiences" do
      assoc = described_class.reflect_on_association(:brand_profiles)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:brand_profile_primary_audiences)
    end
  end

  describe "validations" do
    it "requires a name" do
      pa = build(:primary_audience, name: nil)
      expect(pa).not_to be_valid
      expect(pa.errors[:name]).to include("can't be blank")
    end
  end

  describe "default_scope" do
    it "orders by position" do
      second = create(:primary_audience, position: 2)
      first = create(:primary_audience, position: 1)
      third = create(:primary_audience, position: 3)

      expect(described_class.all.to_a).to eq([first, second, third])
    end
  end
end
