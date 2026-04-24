class Api::AccountsController < Api::BaseController
  def index
    account_users = current_user.account_users.includes(:account)
    clients = accessible_clients.order(:name)
    current_au = account_users.find { |au| au.account_id == @current_account.id }

    current_sub = @current_account&.active_subscription

    render json: {
      current_user_id: current_user.id,
      accounts: account_users.map { |au|
        {
          id: au.account.id,
          name: au.account.name,
          is_agency: au.account.is_agency?,
          is_owner: au.is_owner?,
          is_admin: au.is_admin?,
          is_billing_admin: au.is_billing_admin?
        }
      },
      current_account_id: @current_account&.id,
      is_agency: @current_account&.is_agency?,
      customer_chooses_ai: @current_account&.customer_chooses_ai?,
      account_ai_service_id: @current_account&.ai_service_id,
      account_ai_model_id: @current_account&.ai_model_id,
      is_owner: current_au&.is_owner? || false,
      is_admin: current_au&.is_admin? || false,
      is_billing_admin: current_au&.is_billing_admin? || false,
      clients: clients.map { |c| { id: c.id, name: c.name } },
      current_client_id: @current_client&.id,
      subscription: {
        tier_slug: current_sub&.subscription_tier&.slug,
        tier_name: current_sub&.subscription_tier&.name,
        billing_interval: current_sub&.billing_interval,
        paid_through_date: current_sub&.paid_through_date,
        trial_expired: @current_account&.trial_expired? || false,
        on_free_trial: @current_account&.on_free_trial? || false
      }
    }
  end

  def switch
    account = current_user.accounts.find(params[:account_id])
    session[:current_account_id] = account.id
    session.delete(:current_client_id)
    render json: { current_account_id: account.id }
  end

  def switch_client
    client = accessible_clients.find(params[:client_id])
    session[:current_client_id] = client.id
    render json: { current_client_id: client.id }
  end

  def upgrade_to_agency
    au = @current_account.account_users.find_by(user: current_user)
    unless au&.is_owner?
      return render json: { error: "Only account owners can upgrade to Agency" }, status: :forbidden
    end

    if @current_account.is_agency?
      return render json: { error: "Account is already an Agency" }, status: :unprocessable_entity
    end

    @current_account.transaction do
      @current_account.update!(is_agency: true)

      # Unhide the default "self" client so it appears in the agency client list,
      # and rename it to the account name so the user recognizes it.
      default_client = @current_account.default_client
      if default_client
        default_client.update!(hidden: false, name: @current_account.name)
      end
    end

    render json: { is_agency: true }
  end
end
