# frozen_string_literal: true

class Admin::AiKeysController < Admin::BaseController
  # regenerate this controller with
  # bin/rails generate hot_glue:scaffold AiKey --namespace='admin' --gd --include='ai_service_id:-api_key:**name:'

  helper :hot_glue
  include HotGlue::ControllerHelper
  

  
  before_action :load_ai_key, only: %i[show edit update destroy]
  after_action -> { flash.discard }, if: -> { request.format.symbol == :turbo_stream }
  
  def load_ai_key
    @ai_key = AiKey.find(params[:id])
  end
  
  
  
  def load_all_ai_keys
    @ai_keys = AiKey.includes(:ai_service)
    @pagy, @ai_keys = pagy(@ai_keys)
  end

  def index
    load_all_ai_keys
    
  end

  def new
    @ai_key = AiKey.new
    

    
    @action = 'new' 
  end

  def create
    flash[:notice] = +''
    modified_params = modify_date_inputs_on_params(ai_key_params.dup, nil, {})

    
    @ai_key = AiKey.new(modified_params)
    

      
      
    
    if @ai_key.save
      flash[:notice] = "Successfully created #{@ai_key.to_label}"
      
      load_all_ai_keys
      render :create
    else
      flash[:alert] = "Oops, your Ai Key could not be created. #{@hawk_alarm}"
      @action = 'new'
      render :create, status: :unprocessable_entity
    end
  end



  def show
    redirect_to edit_admin_ai_key_path(@ai_key)
  end

  def edit
    @action = 'edit'
    render :edit
  end

  def update
    flash[:notice] = +''
    flash[:alert] = nil
    

    modified_params = modify_date_inputs_on_params(update_ai_key_params.dup, nil, {})
  
    
      
      
   
    
    @ai_key.assign_attributes(modified_params)
      
      
    if @ai_key.save
      
      
      
      flash[:notice] << "Saved #{@ai_key.to_label}"
      flash[:alert] = @hawk_alarm if @hawk_alarm
      render :update, status: :unprocessable_entity
    else
      flash[:alert] = "Ai Key could not be saved. #{@hawk_alarm}"
      
      @action = 'edit'
      render :update, status: :unprocessable_entity
    end
  end

  def destroy
    
    begin
      @ai_key.destroy!
      flash[:notice] = 'Ai Key successfully deleted'
    rescue ActiveRecord::RecordNotDestroyed => e
      flash[:alert] = 'Ai Key could not be deleted'
    end
    
    load_all_ai_keys
  end



  def ai_key_params
    fields = :ai_service_id, :api_key
    params.require(:ai_key).permit(fields)
  end

  
  def update_ai_key_params
    fields = :ai_service_id, :api_key
    
    params.require(:ai_key).permit(fields)
  end
  

  
  def namespace
    'admin/'
  end
end


