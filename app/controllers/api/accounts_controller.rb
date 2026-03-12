class Api::AccountsController < Api::BaseController
  def index
    accounts = current_user.accounts
    projects = @current_account.projects.visible.order(:name)

    render json: {
      accounts: accounts.map { |a| { id: a.id, name: a.name } },
      current_account_id: @current_account&.id,
      is_agency: @current_account&.is_agency?,
      projects: projects.map { |p| { id: p.id, name: p.name } },
      current_project_id: @current_project&.id
    }
  end

  def switch
    account = current_user.accounts.find(params[:account_id])
    session[:current_account_id] = account.id
    session.delete(:current_project_id)
    render json: { current_account_id: account.id }
  end

  def switch_project
    project = @current_account.projects.visible.find(params[:project_id])
    session[:current_project_id] = project.id
    render json: { current_project_id: project.id }
  end
end
