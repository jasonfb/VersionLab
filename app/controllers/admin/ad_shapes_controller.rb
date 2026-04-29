# frozen_string_literal: true

class Admin::AdShapesController < Admin::BaseController
  # regenerate this controller with
  # bin/rails generate hot_glue:scaffold AdShape --namespace='admin' --downnest='ad_shape_layout_rules' --big-edit --gd --smart-layout

  helper :hot_glue
  include HotGlue::ControllerHelper
  

  
  before_action :load_ad_shape, only: %i[show edit update destroy]
  after_action -> { flash.discard }, if: -> { request.format.symbol == :turbo_stream }
  
  def load_ad_shape
    @ad_shape = AdShape.find(params[:id])
  end
  
  
  
  def load_all_ad_shapes
    @ad_shapes = AdShape.all
    @pagy, @ad_shapes = pagy(@ad_shapes)
  end

  def index
    load_all_ad_shapes
    
  end

  def new
    @ad_shape = AdShape.new
    

    
    @action = 'new' 
  end

  def create
    flash[:notice] = +''
    modified_params = modify_date_inputs_on_params(ad_shape_params.dup, nil, {})

    
    @ad_shape = AdShape.new(modified_params)
    

      
      
    
    if @ad_shape.save
      flash[:notice] = "Successfully created #{@ad_shape.name}"
      
      load_all_ad_shapes
      render :create
    else
      flash[:alert] = "Oops, your Ad Shape could not be created. #{@hawk_alarm}"
      @action = 'new'
      render :create, status: :unprocessable_entity
    end
  end



  def show
    redirect_to edit_admin_ad_shape_path(@ad_shape)
  end

  def edit
    @action = 'edit'
    render :edit
  end

  def update
    flash[:notice] = +''
    flash[:alert] = nil
    

    modified_params = modify_date_inputs_on_params(update_ad_shape_params.dup, nil, {})
  
    
      
      
   
    
    @ad_shape.assign_attributes(modified_params)
      
      
    if @ad_shape.save
      
      
      
      flash[:notice] << "Saved #{@ad_shape.name}"
      flash[:alert] = @hawk_alarm if @hawk_alarm
      
      redirect_to admin_ad_shapes_path
     
    else
      flash[:alert] = "Ad Shape could not be saved. #{@hawk_alarm}"
      
      @action = 'edit'
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    
    begin
      @ad_shape.destroy!
      flash[:notice] = 'Ad Shape successfully deleted'
    rescue ActiveRecord::RecordNotDestroyed => e
      flash[:alert] = 'Ad Shape could not be deleted'
    end
    
    load_all_ad_shapes
  end



  def ad_shape_params
    fields = :name, :min_ratio, :max_ratio, :position
    params.require(:ad_shape).permit(fields)
  end

  
  def update_ad_shape_params
    fields = :name, :min_ratio, :max_ratio, :position
    
    params.require(:ad_shape).permit(fields)
  end
  

  
  def namespace
    'admin/'
  end
end


