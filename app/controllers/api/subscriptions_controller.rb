class Api::SubscriptionsController < Api::BaseController
  before_action :require_billing_access!, only: [:create_payment_intent, :confirm]

  def show
    subscription = @current_account.active_subscription
    tiers = SubscriptionTier.where.not(slug: "free_trial").order(:position)

    render json: {
      subscription: subscription_json(subscription),
      tiers: tiers.map { |t| tier_json(t) },
      stripe_publishable_key: ENV["STRIPE_PUBLISHABLE_KEY"]
    }
  end

  def create_payment_intent
    tier = SubscriptionTier.find_by!(slug: params[:tier_slug])
    billing_interval = params[:billing_interval]

    unless %w[monthly annual].include?(billing_interval)
      return render json: { errors: ["Invalid billing interval"] }, status: :unprocessable_entity
    end

    service = StripeCheckoutService.new(account: @current_account)
    result = service.create_payment_intent(tier: tier, billing_interval: billing_interval)

    render json: result
  rescue StripeCheckoutService::Error => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  def confirm
    service = StripeCheckoutService.new(account: @current_account)
    subscription = service.confirm_payment(
      payment_intent_id: params[:payment_intent_id],
      stripe_payment_method_id: params[:stripe_payment_method_id]
    )

    render json: { subscription: subscription_json(subscription) }
  rescue StripeCheckoutService::Error => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  private

  def subscription_json(subscription)
    return nil unless subscription

    {
      id: subscription.id,
      tier_slug: subscription.subscription_tier.slug,
      tier_name: subscription.subscription_tier.name,
      billing_interval: subscription.billing_interval,
      start_date: subscription.start_date,
      paid_through_date: subscription.paid_through_date,
      is_free_trial: subscription.free_trial?,
      trial_expired: @current_account.trial_expired?,
      is_overdue: subscription.overdue?,
      credit_applied_cents: subscription.credit_applied_cents,
      price_cents: subscription.current_period_price_cents
    }
  end

  def tier_json(tier)
    {
      slug: tier.slug,
      name: tier.name,
      monthly_price_cents: tier.monthly_price_cents,
      annual_price_cents: tier.annual_price_cents
    }
  end
end
