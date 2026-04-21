# == Schema Information
#
# Table name: subscriptions
# Database name: primary
#
#  id                    :uuid             not null, primary key
#  billing_interval      :enum             not null
#  canceled_date         :date
#  credit_applied_cents  :integer
#  paid_through_date     :date             not null
#  prorated_refund_cents :integer
#  start_date            :date             not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :uuid             not null
#  subscription_tier_id  :uuid             not null
#
# Indexes
#
#  index_subscriptions_on_account_id            (account_id)
#  index_subscriptions_on_subscription_tier_id  (subscription_tier_id)
#
require "rails_helper"

RSpec.describe Subscription do
  subject(:subscription) { build(:subscription) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires billing_interval" do
      subscription.billing_interval = nil
      expect(subscription).not_to be_valid
    end

    it "requires start_date" do
      subscription.start_date = nil
      expect(subscription).not_to be_valid
    end

    it "requires paid_through_date" do
      subscription.paid_through_date = nil
      expect(subscription).not_to be_valid
    end
  end

  describe "#active?" do
    it "returns true when not canceled" do
      expect(subscription).to be_active
    end

    it "returns false when canceled" do
      subscription.canceled_date = Date.current
      expect(subscription).not_to be_active
    end
  end

  describe "#current_period_price_cents" do
    it "returns monthly price for monthly subscriptions" do
      subscription.billing_interval = "monthly"
      expect(subscription.current_period_price_cents).to eq(subscription.subscription_tier.monthly_price_cents)
    end

    it "returns annual price for annual subscriptions" do
      subscription.billing_interval = "annual"
      expect(subscription.current_period_price_cents).to eq(subscription.subscription_tier.annual_price_cents)
    end
  end

  describe "scopes" do
    let!(:active_sub) { create(:subscription) }
    let!(:canceled_sub) { create(:subscription, canceled_date: Date.current) }

    it ".active returns only active subscriptions" do
      expect(described_class.active).to contain_exactly(active_sub)
    end

    it ".canceled returns only canceled subscriptions" do
      expect(described_class.canceled).to contain_exactly(canceled_sub)
    end

    it ".pending_final_bill returns canceled subs without final_billed_at" do
      # The let! above already creates active_sub and canceled_sub (which has no final_billed_at)
      billed_sub = create(:subscription, canceled_date: 1.day.ago, final_billed_at: Time.current)
      expect(described_class.pending_final_bill).to include(canceled_sub)
      expect(described_class.pending_final_bill).not_to include(active_sub)
      expect(described_class.pending_final_bill).not_to include(billed_sub)
    end
  end

  describe "#canceled?" do
    it "returns true when canceled_date is set" do
      subscription.canceled_date = Date.current
      expect(subscription).to be_canceled
    end

    it "returns false when canceled_date is nil" do
      expect(subscription).not_to be_canceled
    end
  end

  describe "#pending_final_bill?" do
    it "returns true when canceled and not yet final-billed" do
      subscription.canceled_date = Date.current
      subscription.final_billed_at = nil
      expect(subscription.pending_final_bill?).to be true
    end

    it "returns false when not canceled" do
      expect(subscription.pending_final_bill?).to be false
    end

    it "returns false when canceled but already final-billed" do
      subscription.canceled_date = Date.current
      subscription.final_billed_at = Time.current
      expect(subscription.pending_final_bill?).to be false
    end
  end

  describe "#fully_canceled?" do
    it "returns true when canceled and final-billed" do
      subscription.canceled_date = Date.current
      subscription.final_billed_at = Time.current
      expect(subscription.fully_canceled?).to be true
    end

    it "returns false when canceled but not final-billed" do
      subscription.canceled_date = Date.current
      subscription.final_billed_at = nil
      expect(subscription.fully_canceled?).to be false
    end

    it "returns false when not canceled" do
      expect(subscription.fully_canceled?).to be false
    end
  end

  describe "#free_trial?" do
    it "returns true when tier slug is free_trial" do
      tier = build(:subscription_tier, slug: "free_trial")
      subscription.subscription_tier = tier
      expect(subscription.free_trial?).to be true
    end

    it "returns false for other tiers" do
      expect(subscription.free_trial?).to be false
    end
  end

  describe "#overdue?" do
    it "returns true when active, not free trial, and past paid_through_date" do
      subscription.paid_through_date = 1.day.ago
      expect(subscription.overdue?).to be true
    end

    it "returns false when paid_through_date is in the future" do
      subscription.paid_through_date = 1.day.from_now
      expect(subscription.overdue?).to be false
    end

    it "returns false when canceled" do
      subscription.canceled_date = Date.current
      subscription.paid_through_date = 1.day.ago
      expect(subscription.overdue?).to be false
    end

    it "returns false for free trial subscriptions" do
      subscription.subscription_tier = build(:subscription_tier, slug: "free_trial")
      subscription.paid_through_date = 1.day.ago
      expect(subscription.overdue?).to be false
    end
  end

  describe "#effective_monthly_token_allotment" do
    it "returns the tier default when no override is set" do
      expect(subscription.effective_monthly_token_allotment).to eq(1000)
    end

    it "returns the override when set" do
      subscription.monthly_token_allotment_override = 5000
      expect(subscription.effective_monthly_token_allotment).to eq(5000)
    end
  end

  describe "#overage_cents_per_1000_tokens" do
    it "delegates to the subscription tier" do
      expect(subscription.overage_cents_per_1000_tokens).to eq(500)
    end
  end

  describe "token cycle methods" do
    before do
      subscription.token_cycle_started_on = Date.new(2026, 3, 1)
    end

    it "#current_token_cycle_start returns token_cycle_started_on" do
      expect(subscription.current_token_cycle_start).to eq(Date.new(2026, 3, 1))
    end

    it "#current_token_cycle_end returns one month later" do
      expect(subscription.current_token_cycle_end).to eq(Date.new(2026, 4, 1))
    end

    it "#token_cycle_due? returns true when current date is past cycle end" do
      subscription.token_cycle_started_on = 2.months.ago.to_date
      expect(subscription.token_cycle_due?).to be true
    end

    it "#token_cycle_due? returns false when cycle is still running" do
      subscription.token_cycle_started_on = Date.current
      expect(subscription.token_cycle_due?).to be false
    end
  end

  describe "token usage and overage" do
    let(:account) { create(:account) }
    let(:ai_model) { create(:ai_model, input_cost_per_mtok_cents: 300, output_cost_per_mtok_cents: 1500) }
    let!(:sub) do
      create(:subscription,
        account: account,
        token_cycle_started_on: Date.current.beginning_of_month)
    end

    it "#current_cycle_vl_tokens_used sums AI log costs as VL tokens" do
      create(:ai_log, account: account, ai_model: ai_model, call_type: "email",
        prompt_tokens: 1000, completion_tokens: 500, total_tokens: 1500)
      # cost = ceil((1000*300)/1M + (500*1500)/1M) = ceil(0.3 + 0.75) = ceil(1.05) = 2 cents
      # VL tokens = 2 * 10 = 20
      expect(sub.current_cycle_vl_tokens_used).to eq(20)
    end

    it "#current_cycle_overage_tokens returns 0 when within allotment" do
      expect(sub.current_cycle_overage_tokens).to eq(0)
    end

    it "#current_cycle_overage_tokens returns excess when over allotment" do
      sub.monthly_token_allotment_override = 10
      # Create enough logs to exceed 10 VL tokens
      create(:ai_log, account: account, ai_model: ai_model, call_type: "email",
        prompt_tokens: 100_000, completion_tokens: 50_000, total_tokens: 150_000)
      expect(sub.current_cycle_overage_tokens).to be > 0
    end

    it "#current_cycle_overage_cents calculates overage charges" do
      sub.monthly_token_allotment_override = 0
      create(:ai_log, account: account, ai_model: ai_model, call_type: "email",
        prompt_tokens: 100_000, completion_tokens: 50_000, total_tokens: 150_000)
      expect(sub.current_cycle_overage_cents).to be > 0
    end
  end

  describe "#overage_for_window" do
    let(:account) { create(:account) }
    let(:ai_model) { create(:ai_model, input_cost_per_mtok_cents: 300, output_cost_per_mtok_cents: 1500) }
    let!(:sub) { create(:subscription, account: account) }

    it "returns a hash with vl_tokens_used, overage_tokens, and overage_cents" do
      result = sub.overage_for_window(1.month.ago.to_date, Date.current)
      expect(result).to have_key(:vl_tokens_used)
      expect(result).to have_key(:overage_tokens)
      expect(result).to have_key(:overage_cents)
    end

    it "calculates zero overage when under allotment" do
      result = sub.overage_for_window(1.month.ago.to_date, Date.current)
      expect(result[:overage_tokens]).to eq(0)
      expect(result[:overage_cents]).to eq(0)
    end

    it "calculates correct overage for a window with usage" do
      sub.monthly_token_allotment_override = 0
      create(:ai_log, account: account, ai_model: ai_model, call_type: "email",
        prompt_tokens: 100_000, completion_tokens: 50_000, total_tokens: 150_000,
        created_at: 1.day.ago)
      result = sub.overage_for_window(2.days.ago.to_date, Date.current)
      expect(result[:vl_tokens_used]).to be > 0
      expect(result[:overage_tokens]).to eq(result[:vl_tokens_used])
      expect(result[:overage_cents]).to be > 0
    end
  end
end
