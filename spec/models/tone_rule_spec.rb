require 'rails_helper'

RSpec.describe ToneRule, type: :model do
  describe "associations" do
    it "has many brand_profile_tone_rules" do
      assoc = described_class.reflect_on_association(:brand_profile_tone_rules)
      expect(assoc.macro).to eq(:has_many)
    end

    it "has many brand_profiles through brand_profile_tone_rules" do
      assoc = described_class.reflect_on_association(:brand_profiles)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:brand_profile_tone_rules)
    end
  end

  describe "validations" do
    it "requires a name" do
      tone_rule = build(:tone_rule, name: nil)
      expect(tone_rule).not_to be_valid
      expect(tone_rule.errors[:name]).to include("can't be blank")
    end
  end

  describe "default_scope" do
    it "orders by position" do
      second = create(:tone_rule, position: 2)
      first = create(:tone_rule, position: 1)
      third = create(:tone_rule, position: 3)

      expect(described_class.all.to_a).to eq([first, second, third])
    end
  end
end
