class Api::PaymentsController < Api::BaseController
  before_action :require_billing_access!

  def index
    payments = @current_account.payments
      .includes(:subscription, :payment_method)
      .recent
      .limit(50)

    render json: payments.map { |p|
      {
        id: p.id,
        amount_cents: p.amount_cents,
        currency: p.currency,
        status: p.status,
        description: p.description,
        failure_reason: p.failure_reason,
        card_display: p.payment_method&.display_name,
        created_at: p.created_at
      }
    }
  end
end
