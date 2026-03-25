require 'rails_helper'

RSpec.describe BrandProfilePrimaryAudience, type: :model do
  describe "associations" do
    it "belongs to brand_profile" do
      assoc = described_class.reflect_on_association(:brand_profile)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to primary_audience" do
      assoc = described_class.reflect_on_association(:primary_audience)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end
end
