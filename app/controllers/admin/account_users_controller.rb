# frozen_string_literal: true

class Admin::AccountUsersController < Admin::BaseController
  # regenerate this controller with
  # bin/rails generate hot_glue:scaffold AccountUser --namespace='admin' --smart-layout --gd --nested='account' --no-nav-menu

  helper :hot_glue
  include HotGlue::ControllerHelper




  before_action :account
  before_action :load_account_user, only: %i[show edit update destroy]
  after_action -> { flash.discard }, if: -> { request.format.symbol == :turbo_stream }

  def account
    @account ||= Account.find(params[:account_id])
  end



  def load_account_user
    @account_user = account.account_users.find(params[:id])
  end



  def load_all_account_users
    @account_users = account.account_users.includes(:user)
    @pagy, @account_users = pagy(@account_users)
  end

  def index
    load_all_account_users
  end

  def new
    @account_user = AccountUser.new(account: account)



    @action = "new"
  end

  def create
    flash[:notice] = +""
    modified_params = modify_date_inputs_on_params(account_user_params.dup, nil, {})
    modified_params = modified_params.merge(account: account)


    @account_user = AccountUser.new(modified_params)





    if @account_user.save
      flash[:notice] = "Successfully created #{@account_user.to_label}"
      account.reload
      load_all_account_users
      render :create
    else
      flash[:alert] = "Oops, your Account User could not be created. #{@hawk_alarm}"
      @action = "new"
      render :create, status: :unprocessable_entity
    end
  end



  def show
    redirect_to edit_admin_account_account_user_path(@account, @account_user)
  end

  def edit
    @action = "edit"
    render :edit
  end

  def update
    flash[:notice] = +""
    flash[:alert] = nil


    modified_params = modify_date_inputs_on_params(update_account_user_params.dup, nil, {})






    @account_user.assign_attributes(modified_params)


    if @account_user.save
      account.reload


      flash[:notice] << "Saved #{@account_user.to_label}"
      flash[:alert] = @hawk_alarm if @hawk_alarm
      render :update, status: :unprocessable_entity
    else
      flash[:alert] = "Account User could not be saved. #{@hawk_alarm}"

      @action = "edit"
      render :update, status: :unprocessable_entity
    end
  end

  def destroy
    begin
      @account_user.destroy!
      flash[:notice] = "Account User successfully deleted"
    rescue ActiveRecord::RecordNotDestroyed => e
      flash[:alert] = "Account User could not be deleted"
    end
    account.reload
    load_all_account_users
  end



  def account_user_params
    fields = :is_owner, :user_id, :is_admin, :is_billing_admin
    params.require(:account_user).permit(fields)
  end


  def update_account_user_params
    fields = :is_owner, :user_id, :is_admin, :is_billing_admin

    params.require(:account_user).permit(fields)
  end



  def namespace
    "admin/"
  end
end
