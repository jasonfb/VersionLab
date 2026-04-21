# == Schema Information
#
# Table name: payments
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  amount_cents             :integer          not null
#  currency                 :string           default("usd"), not null
#  description              :string
#  failure_reason           :text
#  status                   :enum             not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :uuid             not null
#  payment_method_id        :uuid
#  stripe_payment_intent_id :string
#  subscription_id          :uuid
#
# Indexes
#
#  index_payments_on_account_id                (account_id)
#  index_payments_on_stripe_payment_intent_id  (stripe_payment_intent_id) UNIQUE
#  index_payments_on_subscription_id           (subscription_id)
#
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

  describe "associations" do
    it "belongs to account" do
      assoc = described_class.reflect_on_association(:account)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to subscription (optional)" do
      assoc = described_class.reflect_on_association(:subscription)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to eq(true)
    end

    it "belongs to payment_method (optional)" do
      assoc = described_class.reflect_on_association(:payment_method)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to eq(true)
    end

    it "belongs to invoice (optional)" do
      assoc = described_class.reflect_on_association(:invoice)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to eq(true)
    end
  end

  describe "enums" do
    it "defines all status values" do
      expect(described_class.statuses).to eq(
        "succeeded" => "succeeded", "failed" => "failed",
        "pending" => "pending", "refunded" => "refunded"
      )
    end

    it "supports succeeded status" do
      payment.status = "succeeded"
      expect(payment).to be_succeeded
    end

    it "supports failed status" do
      payment.status = "failed"
      expect(payment).to be_failed
    end

    it "supports pending status" do
      payment.status = "pending"
      expect(payment).to be_pending
    end

    it "supports refunded status" do
      payment.status = "refunded"
      expect(payment).to be_refunded
    end
  end
end
