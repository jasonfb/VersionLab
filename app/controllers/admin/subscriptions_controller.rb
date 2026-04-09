# frozen_string_literal: true

class Admin::SubscriptionsController < Admin::BaseController
  before_action :load_subscription, only: %i[edit update]

  def edit
    @action = "edit"
  end

  def update
    if @subscription.update(subscription_params)
      flash[:notice] = "Saved subscription token override"
      redirect_to edit_admin_account_path(@subscription.account)
    else
      flash[:alert] = "Could not save: #{@subscription.errors.full_messages.to_sentence}"
      @action = "edit"
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_subscription
    @subscription = Subscription.find(params[:id])
  end

  def subscription_params
    params.require(:subscription).permit(:monthly_token_allotment_override)
  end
end
