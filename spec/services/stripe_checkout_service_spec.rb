require "rails_helper"

RSpec.describe StripeCheckoutService do
  let(:account) { create(:account, stripe_customer_id: "cus_test") }
  let(:standard_tier) { create(:subscription_tier, slug: "standard", monthly_price_cents: 4900, annual_price_cents: 49900) }
  let(:agency_tier) { create(:subscription_tier, :agency, slug: "agency", monthly_price_cents: 9900, annual_price_cents: 99900) }

  describe "#create_payment_intent" do
    before do
      allow(Stripe::Customer).to receive(:create).and_return(double(id: "cus_test"))
    end

    it "creates a Stripe PaymentIntent with the correct amount" do
      fake_intent = double(client_secret: "pi_secret", id: "pi_123")
      allow(Stripe::PaymentIntent).to receive(:create).and_return(fake_intent)

      service = described_class.new(account: account)
      result = service.create_payment_intent(tier: standard_tier, billing_interval: "monthly")

      expect(result[:client_secret]).to eq("pi_secret")
      expect(result[:amount_cents]).to eq(4900)
      expect(result[:credit_cents]).to eq(0)

      expect(Stripe::PaymentIntent).to have_received(:create).with(hash_including(
        amount: 4900,
        currency: "usd",
        customer: "cus_test",
        setup_future_usage: "off_session"
      ))
    end

    it "subtracts prorated credit when upgrading from an existing subscription" do
      create(:subscription,
        account: account,
        subscription_tier: standard_tier,
        billing_interval: "monthly",
        start_date: Date.current - 15.days,
        paid_through_date: Date.current + 15.days)

      fake_intent = double(client_secret: "pi_secret", id: "pi_456")
      allow(Stripe::PaymentIntent).to receive(:create).and_return(fake_intent)

      service = described_class.new(account: account)
      result = service.create_payment_intent(tier: agency_tier, billing_interval: "monthly")

      # Credit: 15 remaining / 30 total * 4900 = 2450
      expect(result[:credit_cents]).to eq(2450)
      expect(result[:amount_cents]).to eq(9900 - 2450)
    end
  end

  describe "#confirm_payment" do
    let(:fake_intent) do
      double(
        status: "succeeded",
        amount: 4900,
        payment_method: "pm_test_1",
        metadata: {
          "tier_slug" => "standard",
          "billing_interval" => "monthly",
          "credit_applied_cents" => "0"
        }
      )
    end

    let(:fake_stripe_pm) do
      double(
        customer: "cus_test",
        card: double(brand: "visa", last4: "4242", exp_month: 12, exp_year: 2028)
      )
    end

    before do
      standard_tier # ensure it exists
      allow(Stripe::PaymentIntent).to receive(:retrieve).and_return(fake_intent)
      allow(Stripe::PaymentMethod).to receive(:retrieve).and_return(fake_stripe_pm)
      allow(Stripe::PaymentMethod).to receive(:attach)
    end

    it "creates a subscription and records a payment" do
      service = described_class.new(account: account)
      subscription = service.confirm_payment(
        payment_intent_id: "pi_test",
        stripe_payment_method_id: "pm_test_1"
      )

      expect(subscription).to be_persisted
      expect(subscription.subscription_tier).to eq(standard_tier)
      expect(subscription.billing_interval).to eq("monthly")

      payment = account.payments.last
      expect(payment.amount_cents).to eq(4900)
      expect(payment.status).to eq("succeeded")
    end

    it "stores the payment method" do
      service = described_class.new(account: account)
      service.confirm_payment(
        payment_intent_id: "pi_test",
        stripe_payment_method_id: "pm_test_1"
      )

      pm = account.payment_methods.first
      expect(pm.stripe_payment_method_id).to eq("pm_test_1")
      expect(pm.card_brand).to eq("visa")
      expect(pm.card_last4).to eq("4242")
      expect(pm.is_default).to be true
    end

    it "cancels existing subscription when upgrading" do
      free_trial_tier = create(:subscription_tier, slug: "free_trial", name: "Free Trial",
        monthly_price_cents: 0, annual_price_cents: 0)
      existing = create(:subscription,
        account: account,
        subscription_tier: free_trial_tier,
        billing_interval: "monthly",
        start_date: Date.current - 3.days,
        paid_through_date: Date.current + 4.days)

      service = described_class.new(account: account)
      service.confirm_payment(
        payment_intent_id: "pi_test",
        stripe_payment_method_id: "pm_test_1"
      )

      expect(existing.reload.canceled_date).to eq(Date.current)
    end

    it "raises error if payment not succeeded" do
      failed_intent = double(status: "requires_payment_method", metadata: {})
      allow(Stripe::PaymentIntent).to receive(:retrieve).and_return(failed_intent)

      service = described_class.new(account: account)
      expect {
        service.confirm_payment(payment_intent_id: "pi_fail", stripe_payment_method_id: "pm_1")
      }.to raise_error(described_class::Error, "Payment not succeeded")
    end
  end
end
