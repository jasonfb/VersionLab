require "rails_helper"

RSpec.describe BillingService do
  let(:account) { create(:account, stripe_customer_id: "cus_test") }
  let(:tier) { create(:subscription_tier, slug: "standard", monthly_price_cents: 4900, annual_price_cents: 49900) }
  let!(:payment_method) { create(:payment_method, account: account, is_default: true) }

  let(:fake_intent) { double(status: "succeeded", id: "pi_test_#{SecureRandom.hex(4)}") }

  before do
    allow(Stripe::PaymentIntent).to receive(:create).and_return(fake_intent)
    allow(InvoiceMailer).to receive_message_chain(:issued, :deliver_later)
  end

  describe "#process" do
    it "skips free trial subscriptions" do
      free_tier = create(:subscription_tier, slug: "free_trial", monthly_price_cents: 0, annual_price_cents: 0)
      sub = create(:subscription, account: account, subscription_tier: free_tier,
                   paid_through_date: 1.day.ago)
      described_class.process(sub)
      expect(account.invoices.count).to eq(0)
    end

    it "skips active subscriptions that are not due" do
      sub = create(:subscription, account: account, subscription_tier: tier,
                   paid_through_date: 10.days.from_now,
                   token_cycle_started_on: Date.current)
      described_class.process(sub)
      expect(account.invoices.count).to eq(0)
    end

    context "base renewal" do
      it "creates invoice and charges when paid_through_date is past" do
        sub = create(:subscription, account: account, subscription_tier: tier,
                     billing_interval: "monthly",
                     paid_through_date: 1.day.ago,
                     token_cycle_started_on: Date.current)
        described_class.process(sub)

        expect(account.invoices.count).to eq(1)
        invoice = account.invoices.last
        expect(invoice.status).to eq("paid")
        expect(invoice.total_cents).to eq(4900)

        expect(sub.reload.paid_through_date).to eq(1.day.ago.to_date + 1.month)
      end

      it "advances paid_through_date by 1 year for annual subs" do
        sub = create(:subscription, account: account, subscription_tier: tier,
                     billing_interval: "annual",
                     paid_through_date: 1.day.ago,
                     token_cycle_started_on: Date.current)
        described_class.process(sub)
        expect(sub.reload.paid_through_date).to eq(1.day.ago.to_date + 1.year)
      end
    end

    context "token cycle overage" do
      it "bills for overage when token cycle has elapsed" do
        ai_model = create(:ai_model, input_cost_per_mtok_cents: 300, output_cost_per_mtok_cents: 1500)
        sub = create(:subscription, account: account, subscription_tier: tier,
                     billing_interval: "monthly",
                     paid_through_date: 10.days.from_now,
                     token_cycle_started_on: 2.months.ago.to_date,
                     monthly_token_allotment_override: 0) # force all usage to be overage

        # Create some AI usage in the first cycle
        create(:ai_log, account: account, ai_model: ai_model,
               ai_service: ai_model.ai_service,
               prompt_tokens: 1_000_000, completion_tokens: 500_000,
               total_tokens: 1_500_000, call_type: "email",
               created_at: (2.months.ago + 1.day))

        described_class.process(sub)

        expect(account.invoices.count).to eq(1)
        invoice = account.invoices.last
        overage_items = invoice.line_items.where(kind: "overage")
        expect(overage_items.count).to be >= 1
      end
    end

    context "failed payment" do
      it "records failed payment and does not advance dates" do
        failed_intent = double(status: "requires_payment_method", id: "pi_fail")
        allow(Stripe::PaymentIntent).to receive(:create).and_return(failed_intent)

        sub = create(:subscription, account: account, subscription_tier: tier,
                     billing_interval: "monthly",
                     paid_through_date: 1.day.ago,
                     token_cycle_started_on: Date.current)
        original_date = sub.paid_through_date

        described_class.process(sub)

        expect(account.payments.last.status).to eq("failed")
        expect(sub.reload.paid_through_date).to eq(original_date)
      end

      it "handles Stripe::CardError" do
        allow(Stripe::PaymentIntent).to receive(:create).and_raise(
          Stripe::CardError.new("Card declined", nil, code: "card_declined")
        )

        sub = create(:subscription, account: account, subscription_tier: tier,
                     billing_interval: "monthly",
                     paid_through_date: 1.day.ago,
                     token_cycle_started_on: Date.current)

        described_class.process(sub)

        expect(account.payments.last.status).to eq("failed")
        expect(account.payments.last.failure_reason).to include("declined")
      end
    end

    context "missing payment method" do
      it "records failed payment without calling Stripe" do
        account_no_pm = create(:account, stripe_customer_id: "cus_no_pm")
        sub = create(:subscription, account: account_no_pm, subscription_tier: tier,
                     billing_interval: "monthly",
                     paid_through_date: 1.day.ago,
                     token_cycle_started_on: Date.current)

        expect(Stripe::PaymentIntent).not_to receive(:create)
        described_class.process(sub)

        expect(account_no_pm.payments.last.status).to eq("failed")
        expect(account_no_pm.payments.last.failure_reason).to include("No payment method")
      end
    end

    context "final overage billing for canceled subs" do
      it "bills final overage and marks as fully canceled" do
        sub = create(:subscription, account: account, subscription_tier: tier,
                     billing_interval: "monthly",
                     canceled_date: 1.day.ago,
                     final_billed_at: nil,
                     token_cycle_started_on: 1.month.ago.to_date,
                     monthly_token_allotment_override: 0)

        ai_model = create(:ai_model, input_cost_per_mtok_cents: 300, output_cost_per_mtok_cents: 1500)
        create(:ai_log, account: account, ai_model: ai_model,
               ai_service: ai_model.ai_service,
               prompt_tokens: 1_000_000, completion_tokens: 500_000,
               total_tokens: 1_500_000, call_type: "email",
               created_at: 2.days.ago)

        described_class.process(sub)

        expect(sub.reload.final_billed_at).to be_present
      end

      it "closes canceled sub even with zero overage" do
        sub = create(:subscription, account: account, subscription_tier: tier,
                     canceled_date: 1.day.ago,
                     final_billed_at: nil,
                     token_cycle_started_on: Date.current)

        described_class.process(sub)

        expect(sub.reload.final_billed_at).to be_present
        expect(account.invoices.count).to eq(0) # no invoice when $0 overage
      end
    end
  end
end
