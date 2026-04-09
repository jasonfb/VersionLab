# Single entry point for all subscription billing actions.
#
# Run #process(subscription) once per subscription per day. It handles, in order:
#
#   1. Final overage billing for canceled subs that haven't been final-billed yet.
#   2. Token cycle rollovers (every 1 calendar month, both monthly and annual subs)
#      — accumulates overage line items and advances `token_cycle_started_on`.
#   3. Base subscription renewals when `paid_through_date <= today`.
#
# Steps 2 and 3 produce a single Invoice with multiple line items when both
# happen on the same day (typical for monthly plans), so the customer sees one
# unified bill rather than two separate charges.
class BillingService
  class Error < StandardError; end

  def self.process(subscription)
    new(subscription).process
  end

  def initialize(subscription)
    @subscription = subscription
    @account = subscription.account
  end

  def process
    return if @subscription.free_trial?

    if @subscription.pending_final_bill?
      bill_final_overage_and_close
      return
    end

    return unless @subscription.active?

    invoice_line_items = []
    new_token_cycle_started_on = @subscription.token_cycle_started_on
    new_paid_through_date = @subscription.paid_through_date

    # 1. Roll over any elapsed token cycles (overage line items)
    while Date.current >= new_token_cycle_started_on + 1.month
      cycle_start = new_token_cycle_started_on
      cycle_end = new_token_cycle_started_on + 1.month
      overage = @subscription.overage_for_window(cycle_start, cycle_end)
      if overage[:overage_cents].positive?
        invoice_line_items << overage_line_item(cycle_start, cycle_end, overage)
      end
      new_token_cycle_started_on = cycle_end
    end

    # 2. Renew base subscription price if billing period elapsed
    if @subscription.paid_through_date <= Date.current
      invoice_line_items << base_renewal_line_item
      new_paid_through_date = next_paid_through(@subscription.paid_through_date)
    end

    return if invoice_line_items.empty?

    invoice = nil
    Subscription.transaction do
      invoice = build_invoice(
        period_start: @subscription.token_cycle_started_on,
        period_end: new_token_cycle_started_on
      )
      invoice_line_items.each { |li| invoice.add_line_item!(**li) }
      invoice.finalize!

      payment = charge_invoice(invoice)
      if payment.succeeded?
        invoice.mark_paid!(payment: payment)
        @subscription.update!(
          token_cycle_started_on: new_token_cycle_started_on,
          paid_through_date: new_paid_through_date
        )
      end
    end

    if invoice&.paid?
      InvoiceMailer.issued(invoice).deliver_later
      invoice.update!(email_sent_at: Time.current)
    end
  end

  private

  def bill_final_overage_and_close
    cycle_start = @subscription.token_cycle_started_on
    cycle_end = @subscription.canceled_date
    overage = @subscription.overage_for_window(cycle_start, cycle_end)

    if overage[:overage_cents].positive?
      Subscription.transaction do
        invoice = build_invoice(period_start: cycle_start, period_end: cycle_end)
        invoice.add_line_item!(**overage_line_item(cycle_start, cycle_end, overage, final: true))
        invoice.finalize!

        payment = charge_invoice(invoice)
        if payment.succeeded?
          invoice.mark_paid!(payment: payment)
          InvoiceMailer.issued(invoice).deliver_later
          invoice.update!(email_sent_at: Time.current)
        end
      end
    end

    @subscription.update!(final_billed_at: Time.current)
  end

  def overage_line_item(cycle_start, cycle_end, overage, final: false)
    label = final ? "Final VL token overage" : "VL token overage"
    {
      kind: :overage,
      description: "#{label} (#{cycle_start.strftime('%b %-d')}–#{cycle_end.strftime('%b %-d, %Y')})",
      quantity: overage[:overage_tokens],
      unit_amount_cents: 0,           # display only — real rate is per-1000
      amount_cents: overage[:overage_cents]
    }
  end

  def base_renewal_line_item
    tier = @subscription.subscription_tier
    interval_label = @subscription.annual? ? "annual" : "monthly"
    price = @subscription.current_period_price_cents
    {
      kind: :subscription,
      description: "#{tier.name} — #{interval_label} subscription",
      quantity: 1,
      unit_amount_cents: price,
      amount_cents: price
    }
  end

  def next_paid_through(current)
    @subscription.annual? ? current + 1.year : current + 1.month
  end

  def build_invoice(period_start:, period_end:)
    @account.invoices.create!(
      subscription: @subscription,
      status: "draft",
      period_start: period_start,
      period_end: period_end
    )
  end

  # Charge the invoice via Stripe and create a Payment record (succeeded
  # or failed). Returns the Payment.
  def charge_invoice(invoice)
    pm = @account.default_payment_method
    unless pm && @account.stripe_customer_id
      Rails.logger.warn("BillingService: missing payment method or Stripe customer for account #{@account.id}")
      return @account.payments.create!(
        subscription: @subscription,
        invoice: invoice,
        amount_cents: invoice.total_cents,
        status: "failed",
        failure_reason: "No payment method on file",
        description: invoice.invoice_number
      )
    end

    intent = Stripe::PaymentIntent.create(
      amount: invoice.total_cents,
      currency: "usd",
      customer: @account.stripe_customer_id,
      payment_method: pm.stripe_payment_method_id,
      off_session: true,
      confirm: true,
      metadata: {
        account_id: @account.id,
        subscription_id: @subscription.id,
        invoice_id: invoice.id,
        invoice_number: invoice.invoice_number
      }
    )

    if intent.status == "succeeded"
      @account.payments.create!(
        subscription: @subscription,
        invoice: invoice,
        payment_method: pm,
        stripe_payment_intent_id: intent.id,
        amount_cents: invoice.total_cents,
        status: "succeeded",
        description: invoice.invoice_number
      )
    else
      @account.payments.create!(
        subscription: @subscription,
        invoice: invoice,
        payment_method: pm,
        stripe_payment_intent_id: intent.id,
        amount_cents: invoice.total_cents,
        status: "failed",
        failure_reason: "Stripe status: #{intent.status}",
        description: invoice.invoice_number
      )
    end
  rescue Stripe::CardError => e
    @account.payments.create!(
      subscription: @subscription,
      invoice: invoice,
      payment_method: pm,
      amount_cents: invoice.total_cents,
      status: "failed",
      failure_reason: e.message,
      description: invoice.invoice_number
    )
  end
end
