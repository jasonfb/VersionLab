class Api::AccountsController < Api::BaseController
  def index
    accounts = current_user.accounts
    render json: {
      accounts: accounts.map { |a| { id: a.id, name: a.name } },
      current_account_id: @current_account&.id
    }
  end

  def switch
    account = current_user.accounts.find(params[:account_id])
    session[:current_account_id] = account.id
    render json: { current_account_id: account.id }
  end
end
