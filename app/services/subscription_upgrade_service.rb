class SubscriptionUpgradeService
  class Error < StandardError; end

  attr_reader :account, :new_tier, :billing_interval

  def initialize(account:, new_tier:, billing_interval: nil)
    @account = account
    @new_tier = new_tier
    @billing_interval = billing_interval
  end

  def call
    ActiveRecord::Base.transaction do
      current_subscription = account.subscriptions.active.first

      if current_subscription
        validate_upgrade!(current_subscription)
        refund_cents = calculate_prorated_refund(current_subscription)
        cancel_subscription!(current_subscription, refund_cents)
        create_subscription!(refund_cents)
      else
        create_subscription!(0)
      end
    end
  end

  private

  def validate_upgrade!(current_subscription)
    if current_subscription.subscription_tier_id == new_tier.id
      raise Error, "Account is already on the #{new_tier.name} tier"
    end
  end

  def calculate_prorated_refund(subscription)
    total_days = days_in_period(subscription)
    return 0 if total_days.zero?

    remaining_days = (subscription.paid_through_date - Date.current).to_i
    remaining_days = [remaining_days, 0].max

    price_cents = subscription.current_period_price_cents
    (price_cents * remaining_days.to_f / total_days).round
  end

  def days_in_period(subscription)
    if subscription.monthly?
      30
    else
      365
    end
  end

  def cancel_subscription!(subscription, refund_cents)
    subscription.update!(
      canceled_date: Date.current,
      prorated_refund_cents: refund_cents
    )
  end

  def create_subscription!(credit_cents)
    interval = billing_interval || account.subscriptions.canceled.order(canceled_date: :desc).first&.billing_interval || "monthly"

    account.subscriptions.create!(
      subscription_tier: new_tier,
      billing_interval: interval,
      start_date: Date.current,
      paid_through_date: calculate_paid_through_date(interval),
      credit_applied_cents: credit_cents.positive? ? credit_cents : nil
    )
  end

  def calculate_paid_through_date(interval)
    if interval == "monthly"
      Date.current + 30.days
    else
      Date.current + 365.days
    end
  end
end
