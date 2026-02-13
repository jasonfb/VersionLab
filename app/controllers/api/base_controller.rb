class Api::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :set_current_account

  private

  def set_current_account
    @current_account = if session[:current_account_id]
      current_user.accounts.find_by(id: session[:current_account_id])
    end
    @current_account ||= current_user.accounts.first
  end
end
