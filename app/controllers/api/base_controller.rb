class Api::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :set_current_account
  before_action :set_current_client

  private

  def set_current_account
    @current_account = if session[:current_account_id]
      current_user.accounts.find_by(id: session[:current_account_id])
    end
    @current_account ||= current_user.accounts.first
  end

  def set_current_client
    if @current_account.is_agency?
      @current_client = if session[:current_client_id]
        accessible_clients.find_by(id: session[:current_client_id])
      end
      @current_client ||= accessible_clients.first
    else
      @current_client = @current_account.default_client
    end
  end

  # Returns the scope of clients the current user may access.
  # Owners and admins see all visible clients; members see only explicitly assigned ones.
  def accessible_clients
    @accessible_clients ||= begin
      au = current_account_user
      if au&.is_owner? || au&.is_admin?
        @current_account.clients.visible
      else
        @current_account.clients.visible
          .joins(:client_users)
          .where(client_users: { user_id: current_user.id })
      end
    end
  end

  def current_account_user
    @current_account_user ||= @current_account.account_users.find_by(user: current_user)
  end
end
