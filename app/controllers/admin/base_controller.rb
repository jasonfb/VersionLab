class Admin::BaseController < ApplicationController
  layout "admin"

  before_action :require_admin!

  private

  def require_admin!
    authenticate_user!
    redirect_to root_path, alert: "Not authorized." unless current_user.admin?
  end
end
