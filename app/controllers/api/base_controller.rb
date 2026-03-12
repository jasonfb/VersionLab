class Api::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :set_current_account
  before_action :set_current_project

  private

  def set_current_account
    @current_account = if session[:current_account_id]
      current_user.accounts.find_by(id: session[:current_account_id])
    end
    @current_account ||= current_user.accounts.first
  end

  def set_current_project
    if @current_account.is_agency?
      @current_project = if session[:current_project_id]
        @current_account.projects.visible.find_by(id: session[:current_project_id])
      end
      @current_project ||= @current_account.projects.visible.first
    else
      @current_project = @current_account.default_project
    end
  end
end
