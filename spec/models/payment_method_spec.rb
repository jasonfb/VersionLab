require "rails_helper"

RSpec.describe PaymentMethod do
  subject(:payment_method) { build(:payment_method) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires stripe_payment_method_id" do
      payment_method.stripe_payment_method_id = nil
      expect(payment_method).not_to be_valid
    end

    it "requires unique stripe_payment_method_id" do
      create(:payment_method, stripe_payment_method_id: "pm_dup")
      payment_method.stripe_payment_method_id = "pm_dup"
      expect(payment_method).not_to be_valid
    end
  end

  describe "#display_name" do
    it "returns formatted card info" do
      payment_method.card_brand = "visa"
      payment_method.card_last4 = "4242"
      expect(payment_method.display_name).to eq("Visa ending in 4242")
    end

    it "handles nil brand" do
      payment_method.card_brand = nil
      payment_method.card_last4 = "1234"
      expect(payment_method.display_name).to eq("Card ending in 1234")
    end
  end
end
