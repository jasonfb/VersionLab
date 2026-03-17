class Api::ClientUsersController < Api::BaseController
  before_action :require_owner_or_admin
  before_action :set_client

  # Returns all account users with their assignment status for this client.
  # Owners & admins are flagged as always_has_access.
  def index
    account_users = @current_account.account_users.includes(:user).order(:created_at)
    explicit_assignments = @client.client_users.index_by(&:user_id)

    render json: account_users.map { |au|
      always = au.is_owner? || au.is_admin?
      cu = explicit_assignments[au.user_id]
      {
        account_user_id: au.id,
        user_id: au.user_id,
        email: au.user.email,
        is_owner: au.is_owner? || false,
        is_admin: au.is_admin? || false,
        always_has_access: always,
        assigned: always || cu.present?,
        client_user_id: cu&.id
      }
    }
  end

  def create
    user = @current_account.users.find(params[:user_id])
    cu = @client.client_users.find_or_create_by!(user: user)
    render json: { client_user_id: cu.id }, status: :created
  end

  def destroy
    cu = @client.client_users.find(params[:id])
    cu.destroy!
    head :no_content
  end

  private

  def require_owner_or_admin
    unless current_account_user&.is_owner? || current_account_user&.is_admin?
      render json: { error: "Access denied" }, status: :forbidden
    end
  end

  def set_client
    @client = @current_account.clients.find(params[:client_id])
  end
end
