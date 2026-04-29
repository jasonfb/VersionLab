# frozen_string_literal: true

class Admin::AdPlatformSizesController < Admin::BaseController
  # regenerate this controller with
  # bin/rails generate hot_glue:scaffold AdPlatformSize --namespace='admin' --nested='ad_platform' --no-nav-menu --gd --include='name:width:height:position:**shape' --force

  helper :hot_glue
  include HotGlue::ControllerHelper
  

  
     
  before_action :ad_platform
  before_action :load_ad_platform_size, only: %i[show edit update destroy]
  after_action -> { flash.discard }, if: -> { request.format.symbol == :turbo_stream }

  def ad_platform
    @ad_platform ||= AdPlatform.find(params[:ad_platform_id]) 
  end
  
    
  
  def load_ad_platform_size
    @ad_platform_size = ad_platform.ad_platform_sizes.find(params[:id])
  end
  
  
  
  def load_all_ad_platform_sizes
    @ad_platform_sizes = ad_platform.ad_platform_sizes.all
    @pagy, @ad_platform_sizes = pagy(@ad_platform_sizes)
  end

  def index
    load_all_ad_platform_sizes
    
  end

  def new
    @ad_platform_size = AdPlatformSize.new(ad_platform: ad_platform)
    

    
    @action = 'new' 
  end

  def create
    flash[:notice] = +''
    modified_params = modify_date_inputs_on_params(ad_platform_size_params.dup, nil, {})
    modified_params = modified_params.merge(ad_platform: ad_platform) 

    
    @ad_platform_size = AdPlatformSize.new(modified_params)
    

      
      
    
    if @ad_platform_size.save
      flash[:notice] = "Successfully created #{@ad_platform_size.name}"
      ad_platform.reload
      load_all_ad_platform_sizes
      render :create
    else
      flash[:alert] = "Oops, your Ad Platform Size could not be created. #{@hawk_alarm}"
      @action = 'new'
      render :create, status: :unprocessable_entity
    end
  end



  def show
    redirect_to edit_admin_ad_platform_ad_platform_size_path(@ad_platform,@ad_platform_size)
  end

  def edit
    @action = 'edit'
    render :edit
  end

  def update
    flash[:notice] = +''
    flash[:alert] = nil
    

    modified_params = modify_date_inputs_on_params(update_ad_platform_size_params.dup, nil, {})
  
    
      
      
   
    
    @ad_platform_size.assign_attributes(modified_params)
      
      
    if @ad_platform_size.save
      ad_platform.reload
      
      
      flash[:notice] << "Saved #{@ad_platform_size.name}"
      flash[:alert] = @hawk_alarm if @hawk_alarm
      render :update, status: :unprocessable_entity
    else
      flash[:alert] = "Ad Platform Size could not be saved. #{@hawk_alarm}"
      
      @action = 'edit'
      render :update, status: :unprocessable_entity
    end
  end

  def destroy
    
    begin
      @ad_platform_size.destroy!
      flash[:notice] = 'Ad Platform Size successfully deleted'
    rescue ActiveRecord::RecordNotDestroyed => e
      flash[:alert] = 'Ad Platform Size could not be deleted'
    end
    ad_platform.reload
    load_all_ad_platform_sizes
  end



  def ad_platform_size_params
    fields = :name, :width, :height, :position
    params.require(:ad_platform_size).permit(fields)
  end

  
  def update_ad_platform_size_params
    fields = :name, :width, :height, :position
    
    params.require(:ad_platform_size).permit(fields)
  end
  

  
  def namespace
    'admin/'
  end
end


