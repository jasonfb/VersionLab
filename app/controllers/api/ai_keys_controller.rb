class Api::AiKeysController < Api::BaseController
  before_action :set_ai_key, only: [:update, :destroy]

  def index
    keys = @current_account.ai_keys.includes(:ai_service).order(created_at: :desc)

    render json: keys.map { |k| ai_key_json(k) }
  end

  def create
    key = @current_account.ai_keys.build(ai_key_params)

    if key.save
      render json: ai_key_json(key), status: :created
    else
      render json: { errors: key.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @ai_key.update(ai_key_params)
      render json: ai_key_json(@ai_key)
    else
      render json: { errors: @ai_key.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @ai_key.destroy
    head :no_content
  end

  private

  def set_ai_key
    @ai_key = @current_account.ai_keys.find(params[:id])
  end

  def ai_key_params
    params.require(:ai_key).permit(:ai_service_id, :api_key, :label)
  end

  def ai_key_json(key)
    {
      id: key.id,
      ai_service_id: key.ai_service_id,
      ai_service_name: key.ai_service.name,
      label: key.label,
      masked_key: mask_key(key.api_key),
      created_at: key.created_at,
      updated_at: key.updated_at
    }
  end

  def mask_key(key)
    return "" if key.blank?
    return "****" if key.length <= 8
    "#{key[0..3]}...#{key[-4..]}"
  end
end
