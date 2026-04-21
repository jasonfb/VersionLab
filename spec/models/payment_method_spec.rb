# == Schema Information
#
# Table name: payment_methods
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  card_brand               :string
#  card_exp_month           :integer
#  card_exp_year            :integer
#  card_last4               :string
#  is_default               :boolean          default(FALSE), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :uuid             not null
#  stripe_payment_method_id :string           not null
#
# Indexes
#
#  index_payment_methods_on_account_id                (account_id)
#  index_payment_methods_on_stripe_payment_method_id  (stripe_payment_method_id) UNIQUE
#
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

  describe "associations" do
    it "belongs to account" do
      assoc = described_class.reflect_on_association(:account)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "has many payments with dependent nullify" do
      assoc = described_class.reflect_on_association(:payments)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:nullify)
    end
  end

  describe "scopes" do
    it ".default_method returns only default payment methods" do
      default_pm = create(:payment_method, is_default: true)
      create(:payment_method, is_default: false)
      expect(described_class.default_method).to contain_exactly(default_pm)
    end
  end
end
