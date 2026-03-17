class Api::AccountUsersController < Api::BaseController
  before_action :require_owner_or_admin
  before_action :set_account_user, only: [:update, :destroy]

  def index
    account_users = @current_account.account_users.includes(:user).order(:created_at)

    # Preload all client assignments for this account's users in one query
    client_user_map = @current_account.clients.visible
      .joins(:client_users)
      .pluck('clients.id', 'clients.name', 'client_users.user_id')
      .each_with_object(Hash.new { |h, k| h[k] = [] }) do |(cid, cname, uid), map|
        map[uid] << { id: cid, name: cname }
      end

    render json: account_users.map { |au| account_user_json(au, client_user_map[au.user_id]) }
  end

  def create
    email = params[:email].to_s.strip.downcase
    return render json: { error: "Email is required" }, status: :unprocessable_entity if email.blank?

    new_user = false
    user = User.find_by(email: email)

    if user.nil?
      user = User.new(email: email, password: SecureRandom.hex(32))
      user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
      unless user.save
        return render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
      new_user = true
    end

    if @current_account.account_users.exists?(user: user)
      return render json: { error: "That user already has access to this account" }, status: :unprocessable_entity
    end

    au = @current_account.account_users.create!(user: user)
    UserMailer.account_invitation(user, @current_account, current_user).deliver_later
    render json: account_user_json(au, []).merge(new_user: new_user), status: :created
  end

  def update
    # Validate role change permissions
    target_owner = @target_au.is_owner?
    requester_au = @current_account.account_users.find_by(user: current_user)

    # Admins cannot modify owners or themselves
    if !requester_au.is_owner?
      if target_owner
        return render json: { error: "Admins cannot modify account owners" }, status: :forbidden
      end
      if @target_au.user_id == current_user.id
        return render json: { error: "You cannot modify your own role" }, status: :forbidden
      end
      # Admins cannot assign/change billing_admin
      if params[:account_user].key?(:is_billing_admin)
        return render json: { error: "Only owners can assign the Billing Admin role" }, status: :forbidden
      end
      # Admins cannot assign owner
      if params[:account_user][:is_owner]
        return render json: { error: "Only owners can assign the Owner role" }, status: :forbidden
      end
    end

    allowed = [:is_admin]
    allowed << :is_billing_admin if requester_au.is_owner?
    allowed << :is_owner if requester_au.is_owner?

    @target_au.update!(account_user_params(allowed))
    render json: account_user_json(@target_au, [])
  end

  def destroy
    requester_au = @current_account.account_users.find_by(user: current_user)

    if @target_au.is_owner? && !requester_au.is_owner?
      return render json: { error: "Admins cannot remove account owners" }, status: :forbidden
    end

    # Prevent removing yourself if you're the only owner
    if @target_au.user_id == current_user.id && @target_au.is_owner?
      remaining_owners = @current_account.account_users.where(is_owner: true).where.not(user_id: current_user.id).count
      if remaining_owners == 0
        return render json: { error: "You are the only owner. Transfer ownership before removing yourself." }, status: :unprocessable_entity
      end
    end

    @target_au.destroy!
    head :no_content
  end

  private

  def require_owner_or_admin
    au = @current_account.account_users.find_by(user: current_user)
    unless au&.is_owner? || au&.is_admin?
      render json: { error: "Access denied" }, status: :forbidden
    end
  end

  def set_account_user
    @target_au = @current_account.account_users.find(params[:id])
  end

  def account_user_params(allowed_keys)
    params.require(:account_user).permit(*allowed_keys)
  end

  def account_user_json(au, assigned_clients = [])
    {
      id: au.id,
      user_id: au.user_id,
      email: au.user.email,
      is_owner: au.is_owner? || false,
      is_admin: au.is_admin? || false,
      is_billing_admin: au.is_billing_admin? || false,
      created_at: au.created_at,
      clients: assigned_clients
    }
  end
end
