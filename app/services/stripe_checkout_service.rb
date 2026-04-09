class StripeCheckoutService
  class Error < StandardError; end

  def initialize(account:)
    @account = account
  end

  def create_payment_intent(tier:, billing_interval:)
    customer_id = StripeCustomerService.new(account: @account).call
    price_cents = billing_interval == "annual" ? tier.annual_price_cents : tier.monthly_price_cents

    credit = calculate_credit
    charge_amount = [price_cents - credit, 50].max # Stripe minimum is 50 cents

    intent = Stripe::PaymentIntent.create(
      amount: charge_amount,
      currency: "usd",
      customer: customer_id,
      setup_future_usage: "off_session",
      metadata: {
        account_id: @account.id,
        tier_slug: tier.slug,
        billing_interval: billing_interval,
        credit_applied_cents: credit
      }
    )

    {
      client_secret: intent.client_secret,
      payment_intent_id: intent.id,
      amount_cents: charge_amount,
      credit_cents: credit
    }
  end

  def confirm_payment(payment_intent_id:, stripe_payment_method_id:)
    intent = Stripe::PaymentIntent.retrieve(payment_intent_id)
    raise Error, "Payment not succeeded" unless intent.status == "succeeded"

    tier_slug = intent.metadata["tier_slug"]
    billing_interval = intent.metadata["billing_interval"]
    credit = intent.metadata["credit_applied_cents"].to_i
    tier = SubscriptionTier.find_by!(slug: tier_slug)

    ActiveRecord::Base.transaction do
      pm = store_payment_method(stripe_payment_method_id)

      current_sub = @account.active_subscription
      if current_sub
        refund_cents = current_sub.free_trial? ? 0 : calculate_prorated_refund(current_sub)
        current_sub.update!(canceled_date: Date.current, prorated_refund_cents: refund_cents)
      end

      subscription = @account.subscriptions.create!(
        subscription_tier: tier,
        billing_interval: billing_interval,
        start_date: Date.current,
        token_cycle_started_on: Date.current,
        paid_through_date: calculate_paid_through(billing_interval),
        credit_applied_cents: credit.positive? ? credit : nil
      )

      invoice = @account.invoices.create!(
        subscription: subscription,
        status: "draft",
        period_start: Date.current,
        period_end: subscription.paid_through_date
      )
      invoice.add_line_item!(
        kind: :subscription,
        description: "#{tier.name} — #{billing_interval} subscription",
        quantity: 1,
        unit_amount_cents: intent.amount,
        amount_cents: intent.amount
      )
      if credit.positive?
        invoice.add_line_item!(
          kind: :credit,
          description: "Prorated credit applied",
          quantity: 1,
          unit_amount_cents: -credit,
          amount_cents: -credit
        )
      end
      invoice.finalize!

      payment = @account.payments.create!(
        subscription: subscription,
        invoice: invoice,
        payment_method: pm,
        stripe_payment_intent_id: payment_intent_id,
        amount_cents: intent.amount,
        status: "succeeded",
        description: invoice.invoice_number
      )
      invoice.mark_paid!(payment: payment)

      InvoiceMailer.issued(invoice).deliver_later
      invoice.update!(email_sent_at: Time.current)

      subscription
    end
  end

  private

  def calculate_credit
    current_sub = @account.active_subscription
    return 0 unless current_sub
    return 0 if current_sub.free_trial?

    calculate_prorated_refund(current_sub)
  end

  def calculate_prorated_refund(subscription)
    total_days = subscription.monthly? ? 30 : 365
    remaining_days = (subscription.paid_through_date - Date.current).to_i
    remaining_days = [remaining_days, 0].max

    price_cents = subscription.current_period_price_cents
    (price_cents * remaining_days.to_f / total_days).round
  end

  def store_payment_method(stripe_payment_method_id)
    existing = @account.payment_methods.find_by(stripe_payment_method_id: stripe_payment_method_id)
    return existing if existing

    stripe_pm = Stripe::PaymentMethod.retrieve(stripe_payment_method_id)

    # Attach to customer if not already attached
    if stripe_pm.customer != @account.stripe_customer_id
      Stripe::PaymentMethod.attach(stripe_payment_method_id, customer: @account.stripe_customer_id)
    end

    is_first = @account.payment_methods.none?

    @account.payment_methods.create!(
      stripe_payment_method_id: stripe_payment_method_id,
      card_brand: stripe_pm.card&.brand,
      card_last4: stripe_pm.card&.last4,
      card_exp_month: stripe_pm.card&.exp_month,
      card_exp_year: stripe_pm.card&.exp_year,
      is_default: is_first
    )
  end

  def calculate_paid_through(interval)
    if interval == "monthly"
      Date.current + 30.days
    else
      Date.current + 365.days
    end
  end
end
