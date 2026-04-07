# frozen_string_literal: true

class Admin::AccountsController < Admin::BaseController
  # regenerate this controller with
  # bin/rails generate hot_glue:scaffold Account --namespace='admin' --record-scope='.reverse_sort' --smart-layout --gd --downnest='account_users' --big-edit

  helper :hot_glue
  include HotGlue::ControllerHelper
  

  
  before_action :load_account, only: %i[show edit update destroy]
  after_action -> { flash.discard }, if: -> { request.format.symbol == :turbo_stream }
  
  def load_account
    @account = Account.find(params[:id])
  end
  
  
  
  def load_all_accounts
    @accounts = Account.reverse_sort
    @pagy, @accounts = pagy(@accounts)
  end

  def index
    load_all_accounts
    
  end

  def new
    @account = Account.new
    

    
    @action = 'new' 
  end

  def create
    flash[:notice] = +''
    modified_params = modify_date_inputs_on_params(account_params.dup, nil, {})

    
    @account = Account.new(modified_params)
    

      
      
    
    if @account.save
      flash[:notice] = "Successfully created #{@account.name}"
      
      load_all_accounts
      render :create
    else
      flash[:alert] = "Oops, your Account could not be created. #{@hawk_alarm}"
      @action = 'new'
      render :create, status: :unprocessable_entity
    end
  end



  def show
    redirect_to edit_admin_account_path(@account)
  end

  def edit
    @action = 'edit'
    render :edit
  end

  def update
    flash[:notice] = +''
    flash[:alert] = nil
    

    modified_params = modify_date_inputs_on_params(update_account_params.dup, nil, {})
  
    
      
      
   
    
    @account.assign_attributes(modified_params)
      
      
    if @account.save
      
      
      
      flash[:notice] << "Saved #{@account.name}"
      flash[:alert] = @hawk_alarm if @hawk_alarm
      
      redirect_to admin_accounts_path
     
    else
      flash[:alert] = "Account could not be saved. #{@hawk_alarm}"
      
      @action = 'edit'
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    
    begin
      @account.destroy!
      flash[:notice] = 'Account successfully deleted'
    rescue ActiveRecord::RecordNotDestroyed => e
      flash[:alert] = 'Account could not be deleted'
    end
    
    load_all_accounts
  end



  def account_params
    fields = :name, :is_agency, :stripe_customer_id
    params.require(:account).permit(fields)
  end

  
  def update_account_params
    fields = :name, :is_agency, :stripe_customer_id
    
    params.require(:account).permit(fields)
  end
  

  
  def namespace
    'admin/'
  end
end


