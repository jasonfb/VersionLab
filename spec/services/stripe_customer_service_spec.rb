require "rails_helper"

RSpec.describe StripeCustomerService do
  let(:account) { create(:account, name: "Test Co") }

  describe "#call" do
    context "when account has no stripe_customer_id" do
      it "creates a Stripe customer and saves the ID" do
        fake_customer = double(id: "cus_test_123")
        allow(Stripe::Customer).to receive(:create).and_return(fake_customer)

        result = described_class.new(account: account).call

        expect(result).to eq("cus_test_123")
        expect(account.reload.stripe_customer_id).to eq("cus_test_123")
        expect(Stripe::Customer).to have_received(:create).with(
          name: "Test Co",
          metadata: { account_id: account.id }
        )
      end
    end

    context "when account already has a stripe_customer_id" do
      before { account.update!(stripe_customer_id: "cus_existing") }

      it "returns the existing ID without calling Stripe" do
        expect(Stripe::Customer).not_to receive(:create)

        result = described_class.new(account: account).call
        expect(result).to eq("cus_existing")
      end
    end
  end
end
