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
class Subscription < ApplicationRecord
  belongs_to :account
  belongs_to :subscription_tier

  enum :billing_interval, { monthly: "monthly", annual: "annual" }

  validates :billing_interval, presence: true
  validates :start_date, presence: true
  validates :paid_through_date, presence: true

  has_many :payments, dependent: :nullify
  has_many :invoices, dependent: :nullify

  scope :active, -> { where(canceled_date: nil) }
  scope :canceled, -> { where.not(canceled_date: nil) }
  scope :pending_final_bill, -> { where.not(canceled_date: nil).where(final_billed_at: nil) }

  def active?
    canceled_date.nil?
  end

  def canceled?
    canceled_date.present?
  end

  def pending_final_bill?
    canceled? && final_billed_at.nil?
  end

  def fully_canceled?
    canceled? && final_billed_at.present?
  end

  def current_period_price_cents
    monthly? ? subscription_tier.monthly_price_cents : subscription_tier.annual_price_cents
  end

  def free_trial?
    subscription_tier.slug == "free_trial"
  end

  def overdue?
    active? && !free_trial? && paid_through_date < Date.current
  end

  # ── VersionLab Tokens ──────────────────────────────────────────────
  #
  # The "token cycle" is always 1 calendar month long for ALL plans
  # (monthly AND annual). Annual subs renew their base price once a year
  # but reset their token allotment monthly; overage is billed at the
  # end of each token cycle regardless of plan interval.

  # Effective monthly allotment: subscription override (if set), else tier default.
  def effective_monthly_token_allotment
    monthly_token_allotment_override.presence || subscription_tier.monthly_token_allotment
  end

  def overage_cents_per_1000_tokens
    subscription_tier.overage_cents_per_1000_tokens
  end

  # Current token cycle window — always exactly 1 month.
  def current_token_cycle_start
    token_cycle_started_on
  end

  def current_token_cycle_end
    token_cycle_started_on + 1.month
  end

  # True when the current token cycle has elapsed and a rollover/overage
  # bill is due.
  def token_cycle_due?
    Date.current >= current_token_cycle_end
  end

  # Sum cost of all AiLogs in the current token cycle, converted to VL tokens.
  def current_cycle_vl_tokens_used
    vl_tokens_used_between(current_token_cycle_start, current_token_cycle_end)
  end

  def current_cycle_overage_tokens
    [current_cycle_vl_tokens_used - effective_monthly_token_allotment, 0].max
  end

  def current_cycle_overage_cents
    VlToken.overage_cents(current_cycle_overage_tokens, overage_cents_per_1000_tokens)
  end

  # Compute VL tokens used and overage owed for an arbitrary window. Used
  # by BillingService when rolling cycles or final-billing canceled subs.
  def overage_for_window(window_start, window_end)
    used = vl_tokens_used_between(window_start, window_end)
    overage_tokens = [used - effective_monthly_token_allotment, 0].max
    {
      vl_tokens_used: used,
      overage_tokens: overage_tokens,
      overage_cents: VlToken.overage_cents(overage_tokens, overage_cents_per_1000_tokens)
    }
  end

  private

  def vl_tokens_used_between(window_start, window_end)
    cost_cents = account.ai_logs
      .where(created_at: window_start.beginning_of_day..window_end.end_of_day)
      .sum(:_cost_to_us_cents)
    VlToken.from_cost_cents(cost_cents)
  end
end
