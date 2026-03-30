require "rails_helper"

RSpec.describe SubscriptionBillingJob do
  let(:account) { create(:account, stripe_customer_id: "cus_test") }
  let(:standard_tier) { create(:subscription_tier, slug: "standard", monthly_price_cents: 4900, annual_price_cents: 49900) }
  let!(:payment_method) { create(:payment_method, account: account, is_default: true) }

  describe "#perform" do
    it "charges overdue subscriptions" do
      subscription = create(:subscription,
        account: account,
        subscription_tier: standard_tier,
        billing_interval: "monthly",
        start_date: Date.current - 35.days,
        paid_through_date: Date.current - 5.days)

      fake_intent = double(status: "succeeded", id: "pi_renewal", amount: 4900)
      allow(Stripe::PaymentIntent).to receive(:create).and_return(fake_intent)

      described_class.new.perform

      subscription.reload
      expect(subscription.paid_through_date).to eq(Date.current - 5.days + 30.days)
      expect(account.payments.count).to eq(1)
      expect(account.payments.last.status).to eq("succeeded")
    end

    it "does not charge active subscriptions" do
      create(:subscription,
        account: account,
        subscription_tier: standard_tier,
        billing_interval: "monthly",
        paid_through_date: Date.current + 10.days)

      expect(Stripe::PaymentIntent).not_to receive(:create)

      described_class.new.perform
    end

    it "does not charge free trial subscriptions" do
      free_trial_tier = create(:subscription_tier, slug: "free_trial", name: "Free Trial",
        monthly_price_cents: 0, annual_price_cents: 0)

      create(:subscription,
        account: account,
        subscription_tier: free_trial_tier,
        billing_interval: "monthly",
        paid_through_date: Date.current - 1.day)

      expect(Stripe::PaymentIntent).not_to receive(:create)

      described_class.new.perform
    end

    it "records failed payments on card error" do
      subscription = create(:subscription,
        account: account,
        subscription_tier: standard_tier,
        billing_interval: "monthly",
        paid_through_date: Date.current - 1.day)

      allow(Stripe::PaymentIntent).to receive(:create).and_raise(
        Stripe::CardError.new("Your card was declined", nil, code: "card_declined")
      )

      described_class.new.perform

      expect(account.payments.count).to eq(1)
      expect(account.payments.last.status).to eq("failed")
      expect(account.payments.last.failure_reason).to include("declined")
      expect(subscription.reload.paid_through_date).to eq(Date.current - 1.day) # unchanged
    end

    it "skips accounts without a payment method" do
      account_no_pm = create(:account, stripe_customer_id: "cus_no_pm")
      create(:subscription,
        account: account_no_pm,
        subscription_tier: standard_tier,
        billing_interval: "monthly",
        paid_through_date: Date.current - 1.day)

      expect(Stripe::PaymentIntent).not_to receive(:create)

      described_class.new.perform
    end
  end
end
