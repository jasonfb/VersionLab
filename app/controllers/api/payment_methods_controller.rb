class Api::PaymentMethodsController < Api::BaseController
  before_action :require_billing_access!

  def index
    methods = @current_account.payment_methods.order(created_at: :desc)

    render json: methods.map { |pm|
      {
        id: pm.id,
        stripe_payment_method_id: pm.stripe_payment_method_id,
        card_brand: pm.card_brand,
        card_last4: pm.card_last4,
        card_exp_month: pm.card_exp_month,
        card_exp_year: pm.card_exp_year,
        is_default: pm.is_default,
        display_name: pm.display_name
      }
    }
  end

  def destroy
    pm = @current_account.payment_methods.find(params[:id])

    begin
      Stripe::PaymentMethod.detach(pm.stripe_payment_method_id)
    rescue Stripe::InvalidRequestError
      # Already detached from Stripe, continue with local cleanup
    end

    was_default = pm.is_default
    pm.destroy!

    if was_default
      new_default = @current_account.payment_methods.first
      new_default&.update!(is_default: true)
    end

    render json: { success: true }
  end

  def set_default
    pm = @current_account.payment_methods.find(params[:id])

    @current_account.payment_methods.where(is_default: true).update_all(is_default: false)
    pm.update!(is_default: true)

    render json: { success: true }
  end
end
