require 'rails_helper'

RSpec.describe BrandProfileGeography, type: :model do
  describe "associations" do
    it "belongs to brand_profile" do
      assoc = described_class.reflect_on_association(:brand_profile)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to geography" do
      assoc = described_class.reflect_on_association(:geography)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end
end
