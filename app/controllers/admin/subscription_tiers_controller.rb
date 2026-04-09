# frozen_string_literal: true

class Admin::SubscriptionTiersController < Admin::BaseController
  # regenerate this controller with
  # bin/rails generate hot_glue:scaffold SubscriptionTier --namespace='admin' --smart-layout --gd

  helper :hot_glue
  include HotGlue::ControllerHelper
  

  
  before_action :load_subscription_tier, only: %i[show edit update destroy]
  after_action -> { flash.discard }, if: -> { request.format.symbol == :turbo_stream }
  
  def load_subscription_tier
    @subscription_tier = SubscriptionTier.find(params[:id])
  end
  
  
  
  def load_all_subscription_tiers
    @subscription_tiers = SubscriptionTier.all
    @pagy, @subscription_tiers = pagy(@subscription_tiers)
  end

  def index
    load_all_subscription_tiers
    
  end

  def new
    @subscription_tier = SubscriptionTier.new
    

    
    @action = 'new' 
  end

  def create
    flash[:notice] = +''
    modified_params = modify_date_inputs_on_params(subscription_tier_params.dup, nil, {})

    
    @subscription_tier = SubscriptionTier.new(modified_params)
    

      
      
    
    if @subscription_tier.save
      flash[:notice] = "Successfully created #{@subscription_tier.name}"
      
      load_all_subscription_tiers
      render :create
    else
      flash[:alert] = "Oops, your Subscription Tier could not be created. #{@hawk_alarm}"
      @action = 'new'
      render :create, status: :unprocessable_entity
    end
  end



  def show
    redirect_to edit_admin_subscription_tier_path(@subscription_tier)
  end

  def edit
    @action = 'edit'
    render :edit
  end

  def update
    flash[:notice] = +''
    flash[:alert] = nil
    

    modified_params = modify_date_inputs_on_params(update_subscription_tier_params.dup, nil, {})
  
    
      
      
   
    
    @subscription_tier.assign_attributes(modified_params)
      
      
    if @subscription_tier.save
      
      
      
      flash[:notice] << "Saved #{@subscription_tier.name}"
      flash[:alert] = @hawk_alarm if @hawk_alarm
      render :update, status: :unprocessable_entity
    else
      flash[:alert] = "Subscription Tier could not be saved. #{@hawk_alarm}"
      
      @action = 'edit'
      render :update, status: :unprocessable_entity
    end
  end

  def destroy
    
    begin
      @subscription_tier.destroy!
      flash[:notice] = 'Subscription Tier successfully deleted'
    rescue ActiveRecord::RecordNotDestroyed => e
      flash[:alert] = 'Subscription Tier could not be deleted'
    end
    
    load_all_subscription_tiers
  end



  def subscription_tier_params
    fields = :name, :slug, :monthly_price_cents, :annual_price_cents, :monthly_token_allotment, :overage_cents_per_1000_tokens, :position
    params.require(:subscription_tier).permit(fields)
  end

  
  def update_subscription_tier_params
    fields = :name, :slug, :monthly_price_cents, :annual_price_cents, :monthly_token_allotment, :overage_cents_per_1000_tokens, :position
    
    params.require(:subscription_tier).permit(fields)
  end
  

  
  def namespace
    'admin/'
  end
end


