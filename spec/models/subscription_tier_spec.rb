# == Schema Information
#
# Table name: subscription_tiers
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  annual_price_cents  :integer          not null
#  monthly_price_cents :integer          not null
#  name                :string           not null
#  position            :integer          default(0), not null
#  slug                :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_subscription_tiers_on_slug  (slug) UNIQUE
#
require "rails_helper"

RSpec.describe SubscriptionTier do
  subject(:tier) { build(:subscription_tier) }

  describe "associations" do
    it "has many subscriptions with dependent restrict_with_error" do
      assoc = described_class.reflect_on_association(:subscriptions)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:restrict_with_error)
    end
  end

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires a name" do
      tier.name = nil
      expect(tier).not_to be_valid
    end

    it "requires a unique slug" do
      create(:subscription_tier, slug: "standard")
      tier.slug = "standard"
      expect(tier).not_to be_valid
    end

    it "requires monthly_price_cents >= 0" do
      tier.monthly_price_cents = -1
      expect(tier).not_to be_valid
    end

    it "requires annual_price_cents >= 0" do
      tier.annual_price_cents = -1
      expect(tier).not_to be_valid
    end

    it "requires monthly_token_allotment >= 0" do
      tier.monthly_token_allotment = -1
      expect(tier).not_to be_valid
    end

    it "requires overage_cents_per_1000_tokens >= 0" do
      tier.overage_cents_per_1000_tokens = -1
      expect(tier).not_to be_valid
    end
  end

  describe "#monthly_price" do
    it "returns price in dollars" do
      tier.monthly_price_cents = 4900
      expect(tier.monthly_price).to eq(49.0)
    end
  end

  describe "#annual_price" do
    it "returns price in dollars" do
      tier.annual_price_cents = 49900
      expect(tier.annual_price).to eq(499.0)
    end
  end
end
