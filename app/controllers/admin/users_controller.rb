# frozen_string_literal: true

class Admin::UsersController < Admin::BaseController
  # regenerate this controller with
  # bin/rails generate hot_glue:scaffold User --namespace='admin' --record-scope='.reverse_sort' --smart-layout --gd

  helper :hot_glue
  include HotGlue::ControllerHelper
  

  
  before_action :load_user, only: %i[show edit update destroy]
  after_action -> { flash.discard }, if: -> { request.format.symbol == :turbo_stream }
  
  def load_user
    @user = User.find(params[:id])
  end
  
  
  
  def load_all_users
    @users = User.reverse_sort
    @pagy, @users = pagy(@users)
  end

  def index
    load_all_users
    
  end

  def new
    @user = User.new
    

    
    @action = 'new' 
  end

  def create
    flash[:notice] = +''
    modified_params = modify_date_inputs_on_params(user_params.dup, nil, {})

    
    @user = User.new(modified_params)
    

      
      
    
    if @user.save
      flash[:notice] = "Successfully created #{@user.name}"
      
      load_all_users
      render :create
    else
      flash[:alert] = "Oops, your User could not be created. #{@hawk_alarm}"
      @action = 'new'
      render :create, status: :unprocessable_entity
    end
  end



  def show
    redirect_to edit_admin_user_path(@user)
  end

  def edit
    @action = 'edit'
    render :edit
  end

  def update
    flash[:notice] = +''
    flash[:alert] = nil
    

    modified_params = modify_date_inputs_on_params(update_user_params.dup, nil, {})
  
    
      
      
   
    
    @user.assign_attributes(modified_params)
      
      
    if @user.save
      
      
      
      flash[:notice] << "Saved #{@user.name}"
      flash[:alert] = @hawk_alarm if @hawk_alarm
      render :update, status: :unprocessable_entity
    else
      flash[:alert] = "User could not be saved. #{@hawk_alarm}"
      
      @action = 'edit'
      render :update, status: :unprocessable_entity
    end
  end

  def destroy
    
    begin
      @user.destroy!
      flash[:notice] = 'User successfully deleted'
    rescue ActiveRecord::RecordNotDestroyed => e
      flash[:alert] = 'User could not be deleted'
    end
    
    load_all_users
  end



  def user_params
    fields = :email, :name
    params.require(:user).permit(fields)
  end

  
  def update_user_params
    fields = :email, :name
    
    params.require(:user).permit(fields)
  end
  

  
  def namespace
    'admin/'
  end
end


