require 'rails_helper'

RSpec.describe Industry, type: :model do
  describe "associations" do
    it "has many brand_profiles" do
      assoc = described_class.reflect_on_association(:brand_profiles)
      expect(assoc.macro).to eq(:has_many)
    end
  end

  describe "validations" do
    it "requires a name" do
      industry = build(:industry, name: nil)
      expect(industry).not_to be_valid
      expect(industry.errors[:name]).to include("can't be blank")
    end
  end

  describe "default_scope" do
    it "orders by position" do
      second = create(:industry, position: 2)
      first = create(:industry, position: 1)
      third = create(:industry, position: 3)

      expect(described_class.all.to_a).to eq([first, second, third])
    end
  end
end
