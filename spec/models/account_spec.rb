# == Schema Information
#
# Table name: accounts
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  is_agency          :boolean          default(FALSE), not null
#  name               :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  stripe_customer_id :string
#
# Indexes
#
#  index_accounts_on_stripe_customer_id  (stripe_customer_id) UNIQUE
#
require 'rails_helper'

RSpec.describe Account, type: :model do
  describe "associations" do
    it "has many clients" do
      assoc = described_class.reflect_on_association(:clients)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many account_users" do
      assoc = described_class.reflect_on_association(:account_users)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many users through account_users" do
      assoc = described_class.reflect_on_association(:users)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:account_users)
    end

    it "has many ai_usage_summaries" do
      assoc = described_class.reflect_on_association(:ai_usage_summaries)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many ai_logs" do
      assoc = described_class.reflect_on_association(:ai_logs)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end
  end

  describe "#default_client" do
    let(:account) { create(:account) }

    context "when a hidden client exists" do
      let!(:hidden_client) { create(:client, account: account, hidden: true) }
      let!(:visible_client) { create(:client, account: account, hidden: false) }

      it "returns the hidden client" do
        expect(account.default_client).to eq(hidden_client)
      end
    end

    context "when no hidden client exists" do
      let!(:visible_client) { create(:client, account: account, hidden: false) }

      it "returns nil" do
        expect(account.default_client).to be_nil
      end
    end
  end

  describe "associations (extended)" do
    it "has many subscriptions with dependent destroy" do
      assoc = described_class.reflect_on_association(:subscriptions)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many payment_methods with dependent destroy" do
      assoc = described_class.reflect_on_association(:payment_methods)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many payments with dependent destroy" do
      assoc = described_class.reflect_on_association(:payments)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many invoices with dependent destroy" do
      assoc = described_class.reflect_on_association(:invoices)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end
  end

  describe "scopes" do
    it ".reverse_sort orders by created_at desc" do
      old_account = create(:account, created_at: 2.days.ago)
      new_account = create(:account, created_at: 1.hour.ago)
      expect(described_class.reverse_sort.to_a).to eq([new_account, old_account])
    end
  end

  describe "#active_subscription" do
    let(:account) { create(:account) }

    it "returns the active subscription" do
      active = create(:subscription, account: account)
      create(:subscription, account: account, canceled_date: Date.current)
      expect(account.active_subscription).to eq(active)
    end

    it "returns nil when no active subscription exists" do
      create(:subscription, account: account, canceled_date: Date.current)
      expect(account.active_subscription).to be_nil
    end
  end

  describe "#default_payment_method" do
    let(:account) { create(:account) }

    it "returns the default payment method" do
      default_pm = create(:payment_method, account: account, is_default: true)
      create(:payment_method, account: account, is_default: false)
      expect(account.default_payment_method).to eq(default_pm)
    end

    it "falls back to a payment method when none is default" do
      create(:payment_method, account: account, is_default: false)
      create(:payment_method, account: account, is_default: false)
      expect(account.default_payment_method).to be_a(PaymentMethod)
    end

    it "returns nil when no payment methods exist" do
      expect(account.default_payment_method).to be_nil
    end
  end

  describe "#on_free_trial?" do
    let(:account) { create(:account) }

    it "returns true when active subscription is on free_trial tier" do
      tier = create(:subscription_tier, slug: "free_trial")
      create(:subscription, account: account, subscription_tier: tier)
      expect(account.on_free_trial?).to be true
    end

    it "returns false when on a paid tier" do
      create(:subscription, account: account)
      expect(account.on_free_trial?).to be false
    end

    it "returns false when no active subscription" do
      expect(account.on_free_trial?).to be false
    end
  end

  describe "#trial_expired?" do
    let(:account) { create(:account) }

    it "returns true when free trial is past paid_through_date" do
      tier = create(:subscription_tier, slug: "free_trial")
      create(:subscription, account: account, subscription_tier: tier, paid_through_date: 1.day.ago)
      expect(account.trial_expired?).to be true
    end

    it "returns false when free trial is still valid" do
      tier = create(:subscription_tier, slug: "free_trial")
      create(:subscription, account: account, subscription_tier: tier, paid_through_date: 1.day.from_now)
      expect(account.trial_expired?).to be false
    end

    it "returns false for paid subscriptions even if overdue" do
      create(:subscription, account: account, paid_through_date: 1.day.ago)
      expect(account.trial_expired?).to be false
    end

    it "returns false when no subscription exists" do
      expect(account.trial_expired?).to be false
    end
  end
end
