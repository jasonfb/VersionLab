class Api::AiServicesController < Api::BaseController
  def index
    services = if params[:all]
      AiService.includes(:ai_models).order(:name)
    else
      configured_ids = @current_account.ai_keys.pluck(:ai_service_id)
      AiService.where(id: configured_ids).includes(:ai_models).order(:name)
    end

    render json: services.map { |s|
      {
        id: s.id,
        name: s.name,
        slug: s.slug,
        models: s.ai_models.order(:name).map { |m|
          {
            id: m.id,
            name: m.name,
            api_identifier: m.api_identifier,
            for_text: m.for_text,
            for_image: m.for_image
          }
        }
      }
    }
  end
end
