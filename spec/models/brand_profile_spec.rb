require 'rails_helper'

RSpec.describe BrandProfile, type: :model do
  describe "associations" do
    it "belongs to client" do
      assoc = described_class.reflect_on_association(:client)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to organization_type (optional)" do
      assoc = described_class.reflect_on_association(:organization_type)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to eq(true)
    end

    it "belongs to industry (optional)" do
      assoc = described_class.reflect_on_association(:industry)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to eq(true)
    end

    it "has many brand_profile_primary_audiences with dependent destroy" do
      assoc = described_class.reflect_on_association(:brand_profile_primary_audiences)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many primary_audiences through brand_profile_primary_audiences" do
      assoc = described_class.reflect_on_association(:primary_audiences)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:brand_profile_primary_audiences)
    end

    it "has many brand_profile_tone_rules with dependent destroy" do
      assoc = described_class.reflect_on_association(:brand_profile_tone_rules)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many tone_rules through brand_profile_tone_rules" do
      assoc = described_class.reflect_on_association(:tone_rules)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:brand_profile_tone_rules)
    end

    it "has many brand_profile_geographies with dependent destroy" do
      assoc = described_class.reflect_on_association(:brand_profile_geographies)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many geographies through brand_profile_geographies" do
      assoc = described_class.reflect_on_association(:geographies)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:brand_profile_geographies)
    end
  end
end
