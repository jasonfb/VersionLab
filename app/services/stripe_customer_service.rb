class StripeCustomerService
  class Error < StandardError; end

  def initialize(account:)
    @account = account
  end

  def call
    return @account.stripe_customer_id if @account.stripe_customer_id.present?

    customer = Stripe::Customer.create(
      name: @account.name,
      metadata: { account_id: @account.id }
    )

    @account.update!(stripe_customer_id: customer.id)
    customer.id
  end
end
