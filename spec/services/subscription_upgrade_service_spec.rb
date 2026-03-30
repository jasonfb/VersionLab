require "rails_helper"

RSpec.describe SubscriptionUpgradeService do
  let(:account) { create(:account) }
  let(:standard_tier) { create(:subscription_tier, slug: "standard", monthly_price_cents: 4900, annual_price_cents: 49900) }
  let(:agency_tier) { create(:subscription_tier, :agency, slug: "agency", monthly_price_cents: 9900, annual_price_cents: 99900) }

  describe "#call" do
    context "when the account has no existing subscription" do
      it "creates a new subscription" do
        service = described_class.new(account: account, new_tier: standard_tier, billing_interval: "monthly")
        subscription = service.call

        expect(subscription).to be_persisted
        expect(subscription.subscription_tier).to eq(standard_tier)
        expect(subscription.billing_interval).to eq("monthly")
        expect(subscription.start_date).to eq(Date.current)
        expect(subscription.credit_applied_cents).to be_nil
      end
    end

    context "when upgrading from standard to agency (monthly)" do
      let!(:existing_subscription) do
        create(:subscription,
          account: account,
          subscription_tier: standard_tier,
          billing_interval: "monthly",
          start_date: Date.current - 15.days,
          paid_through_date: Date.current + 15.days)
      end

      it "cancels the existing subscription" do
        service = described_class.new(account: account, new_tier: agency_tier, billing_interval: "monthly")
        service.call

        existing_subscription.reload
        expect(existing_subscription.canceled_date).to eq(Date.current)
      end

      it "calculates a prorated refund" do
        service = described_class.new(account: account, new_tier: agency_tier, billing_interval: "monthly")
        service.call

        existing_subscription.reload
        # 15 remaining days out of 30, price 4900 => 2450
        expect(existing_subscription.prorated_refund_cents).to eq(2450)
      end

      it "creates a new subscription with credit applied" do
        service = described_class.new(account: account, new_tier: agency_tier, billing_interval: "monthly")
        new_sub = service.call

        expect(new_sub.subscription_tier).to eq(agency_tier)
        expect(new_sub.credit_applied_cents).to eq(2450)
        expect(new_sub.start_date).to eq(Date.current)
      end
    end

    context "when upgrading from standard to agency (annual)" do
      let!(:existing_subscription) do
        create(:subscription,
          account: account,
          subscription_tier: standard_tier,
          billing_interval: "annual",
          start_date: Date.current - 100.days,
          paid_through_date: Date.current + 265.days)
      end

      it "calculates prorated refund based on annual price" do
        service = described_class.new(account: account, new_tier: agency_tier, billing_interval: "annual")
        service.call

        existing_subscription.reload
        # 265 remaining days out of 365, price 49900 => ~36,227
        expected_refund = (49900 * 265.0 / 365).round
        expect(existing_subscription.prorated_refund_cents).to eq(expected_refund)
      end
    end

    context "when already on the same tier" do
      let!(:existing_subscription) do
        create(:subscription, account: account, subscription_tier: standard_tier)
      end

      it "raises an error" do
        service = described_class.new(account: account, new_tier: standard_tier)
        expect { service.call }.to raise_error(described_class::Error, /already on the Standard tier/)
      end
    end

    context "when subscription is fully used (paid_through_date is in the past)" do
      let!(:existing_subscription) do
        create(:subscription,
          account: account,
          subscription_tier: standard_tier,
          billing_interval: "monthly",
          start_date: Date.current - 35.days,
          paid_through_date: Date.current - 5.days)
      end

      it "gives zero refund" do
        service = described_class.new(account: account, new_tier: agency_tier, billing_interval: "monthly")
        service.call

        existing_subscription.reload
        expect(existing_subscription.prorated_refund_cents).to eq(0)
      end
    end

    context "when no billing_interval is specified" do
      let!(:existing_subscription) do
        create(:subscription,
          account: account,
          subscription_tier: standard_tier,
          billing_interval: "annual",
          start_date: Date.current - 10.days,
          paid_through_date: Date.current + 355.days)
      end

      it "carries over the billing interval from the previous subscription" do
        service = described_class.new(account: account, new_tier: agency_tier)
        new_sub = service.call

        expect(new_sub.billing_interval).to eq("annual")
      end
    end
  end
end
