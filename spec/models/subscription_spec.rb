# == Schema Information
#
# Table name: subscriptions
# Database name: primary
#
#  id                    :uuid             not null, primary key
#  billing_interval      :enum             not null
#  canceled_date         :date
#  credit_applied_cents  :integer
#  paid_through_date     :date             not null
#  prorated_refund_cents :integer
#  start_date            :date             not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :uuid             not null
#  subscription_tier_id  :uuid             not null
#
# Indexes
#
#  index_subscriptions_on_account_id            (account_id)
#  index_subscriptions_on_subscription_tier_id  (subscription_tier_id)
#
require "rails_helper"

RSpec.describe Subscription do
  subject(:subscription) { build(:subscription) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires billing_interval" do
      subscription.billing_interval = nil
      expect(subscription).not_to be_valid
    end

    it "requires start_date" do
      subscription.start_date = nil
      expect(subscription).not_to be_valid
    end

    it "requires paid_through_date" do
      subscription.paid_through_date = nil
      expect(subscription).not_to be_valid
    end
  end

  describe "#active?" do
    it "returns true when not canceled" do
      expect(subscription).to be_active
    end

    it "returns false when canceled" do
      subscription.canceled_date = Date.current
      expect(subscription).not_to be_active
    end
  end

  describe "#current_period_price_cents" do
    it "returns monthly price for monthly subscriptions" do
      subscription.billing_interval = "monthly"
      expect(subscription.current_period_price_cents).to eq(subscription.subscription_tier.monthly_price_cents)
    end

    it "returns annual price for annual subscriptions" do
      subscription.billing_interval = "annual"
      expect(subscription.current_period_price_cents).to eq(subscription.subscription_tier.annual_price_cents)
    end
  end

  describe "scopes" do
    let!(:active_sub) { create(:subscription) }
    let!(:canceled_sub) { create(:subscription, canceled_date: Date.current) }

    it ".active returns only active subscriptions" do
      expect(described_class.active).to contain_exactly(active_sub)
    end

    it ".canceled returns only canceled subscriptions" do
      expect(described_class.canceled).to contain_exactly(canceled_sub)
    end
  end
end
