class SubscriptionBillingJob < ApplicationJob
  queue_as :default

  def perform
    Subscription.active
      .joins(:subscription_tier)
      .where("paid_through_date < ?", Date.current)
      .where.not(subscription_tiers: { slug: "free_trial" })
      .includes(:account, :subscription_tier)
      .find_each do |subscription|
        charge_subscription(subscription)
      end
  end

  private

  def charge_subscription(subscription)
    account = subscription.account
    pm = account.default_payment_method

    unless pm
      Rails.logger.warn("SubscriptionBilling: No payment method for account #{account.id}")
      return
    end

    unless account.stripe_customer_id
      Rails.logger.warn("SubscriptionBilling: No Stripe customer for account #{account.id}")
      return
    end

    amount = subscription.current_period_price_cents

    intent = Stripe::PaymentIntent.create(
      amount: amount,
      currency: "usd",
      customer: account.stripe_customer_id,
      payment_method: pm.stripe_payment_method_id,
      off_session: true,
      confirm: true,
      metadata: { account_id: account.id, subscription_id: subscription.id }
    )

    if intent.status == "succeeded"
      new_paid_through = if subscription.monthly?
        subscription.paid_through_date + 30.days
      else
        subscription.paid_through_date + 365.days
      end

      subscription.update!(paid_through_date: new_paid_through)

      account.payments.create!(
        subscription: subscription,
        payment_method: pm,
        stripe_payment_intent_id: intent.id,
        amount_cents: amount,
        status: "succeeded",
        description: "#{subscription.subscription_tier.name} #{subscription.billing_interval} renewal"
      )
    end
  rescue Stripe::CardError => e
    account.payments.create!(
      subscription: subscription,
      payment_method: pm,
      amount_cents: amount,
      status: "failed",
      failure_reason: e.message,
      description: "Failed renewal: #{subscription.subscription_tier.name}"
    )
    Rails.logger.error("SubscriptionBilling: Failed for account #{account.id}: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("SubscriptionBilling: Unexpected error for account #{account.id}: #{e.message}")
    raise
  end
end
