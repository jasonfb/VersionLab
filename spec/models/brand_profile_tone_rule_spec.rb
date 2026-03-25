require 'rails_helper'

RSpec.describe BrandProfileToneRule, type: :model do
  describe "associations" do
    it "belongs to brand_profile" do
      assoc = described_class.reflect_on_association(:brand_profile)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to tone_rule" do
      assoc = described_class.reflect_on_association(:tone_rule)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end
end
