require 'rails_helper'

RSpec.describe Geography, type: :model do
  describe "associations" do
    it "has many brand_profile_geographies" do
      assoc = described_class.reflect_on_association(:brand_profile_geographies)
      expect(assoc.macro).to eq(:has_many)
    end

    it "has many brand_profiles through brand_profile_geographies" do
      assoc = described_class.reflect_on_association(:brand_profiles)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:brand_profile_geographies)
    end
  end

  describe "validations" do
    it "requires a name" do
      geography = build(:geography, name: nil)
      expect(geography).not_to be_valid
      expect(geography.errors[:name]).to include("can't be blank")
    end
  end

  describe "default_scope" do
    it "orders by position" do
      second = create(:geography, position: 2)
      first = create(:geography, position: 1)
      third = create(:geography, position: 3)

      expect(described_class.all.to_a).to eq([first, second, third])
    end
  end
end
