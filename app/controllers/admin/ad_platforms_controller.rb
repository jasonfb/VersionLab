# frozen_string_literal: true

class Admin::AdPlatformsController < Admin::BaseController
  # regenerate this controller with
  # bin/rails generate hot_glue:scaffold AdPlatform --namespace='admin' --downnest='ad_platform_sizes' --big-edit --gd --smart-layout

  helper :hot_glue
  include HotGlue::ControllerHelper
  

  
  before_action :load_ad_platform, only: %i[show edit update destroy]
  after_action -> { flash.discard }, if: -> { request.format.symbol == :turbo_stream }
  
  def load_ad_platform
    @ad_platform = AdPlatform.find(params[:id])
  end
  
  
  
  def load_all_ad_platforms
    @ad_platforms = AdPlatform.all
    @pagy, @ad_platforms = pagy(@ad_platforms)
  end

  def index
    load_all_ad_platforms
    
  end

  def new
    @ad_platform = AdPlatform.new
    

    
    @action = 'new' 
  end

  def create
    flash[:notice] = +''
    modified_params = modify_date_inputs_on_params(ad_platform_params.dup, nil, {})

    
    @ad_platform = AdPlatform.new(modified_params)
    

      
      
    
    if @ad_platform.save
      flash[:notice] = "Successfully created #{@ad_platform.name}"
      
      load_all_ad_platforms
      render :create
    else
      flash[:alert] = "Oops, your Ad Platform could not be created. #{@hawk_alarm}"
      @action = 'new'
      render :create, status: :unprocessable_entity
    end
  end



  def show
    redirect_to edit_admin_ad_platform_path(@ad_platform)
  end

  def edit
    @action = 'edit'
    render :edit
  end

  def update
    flash[:notice] = +''
    flash[:alert] = nil
    

    modified_params = modify_date_inputs_on_params(update_ad_platform_params.dup, nil, {})
  
    
      
      
   
    
    @ad_platform.assign_attributes(modified_params)
      
      
    if @ad_platform.save
      
      
      
      flash[:notice] << "Saved #{@ad_platform.name}"
      flash[:alert] = @hawk_alarm if @hawk_alarm
      
      redirect_to admin_ad_platforms_path
     
    else
      flash[:alert] = "Ad Platform could not be saved. #{@hawk_alarm}"
      
      @action = 'edit'
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    
    begin
      @ad_platform.destroy!
      flash[:notice] = 'Ad Platform successfully deleted'
    rescue ActiveRecord::RecordNotDestroyed => e
      flash[:alert] = 'Ad Platform could not be deleted'
    end
    
    load_all_ad_platforms
  end



  def ad_platform_params
    fields = :name, :position
    params.require(:ad_platform).permit(fields)
  end

  
  def update_ad_platform_params
    fields = :name, :position
    
    params.require(:ad_platform).permit(fields)
  end
  

  
  def namespace
    'admin/'
  end
end


