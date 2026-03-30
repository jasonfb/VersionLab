require "rails_helper"

RSpec.describe Payment do
  subject(:payment) { build(:payment) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires amount_cents" do
      payment.amount_cents = nil
      expect(payment).not_to be_valid
    end

    it "requires status" do
      payment.status = nil
      expect(payment).not_to be_valid
    end
  end

  describe "scopes" do
    let!(:old_payment) { create(:payment, created_at: 2.days.ago) }
    let!(:new_payment) { create(:payment, created_at: 1.hour.ago) }

    it ".recent orders by created_at desc" do
      expect(described_class.recent).to eq([new_payment, old_payment])
    end
  end

  describe "enum" do
    it "supports succeeded status" do
      payment.status = "succeeded"
      expect(payment).to be_succeeded
    end

    it "supports failed status" do
      payment.status = "failed"
      expect(payment).to be_failed
    end
  end
end
