class SeedAiServicesAndModels < ActiveRecord::Migration[8.1]
  def up
    services = {
      "OpenAI" => {
        slug: "openai",
        models: [
          { name: "GPT-4o", api_identifier: "gpt-4o", for_text: true, for_image: false },
          { name: "GPT-4o Mini", api_identifier: "gpt-4o-mini", for_text: true, for_image: false },
          { name: "GPT-4.1", api_identifier: "gpt-4.1", for_text: true, for_image: false },
          { name: "GPT-4.1 Mini", api_identifier: "gpt-4.1-mini", for_text: true, for_image: false },
          { name: "DALL-E 3", api_identifier: "dall-e-3", for_text: false, for_image: true }
        ]
      },
      "Anthropic" => {
        slug: "anthropic",
        models: [
          { name: "Claude Sonnet 4.5", api_identifier: "claude-sonnet-4-5-20250929", for_text: true, for_image: false },
          { name: "Claude Haiku 3.5", api_identifier: "claude-haiku-3-5-20241022", for_text: true, for_image: false }
        ]
      },
      "Google" => {
        slug: "google",
        models: [
          { name: "Gemini 2.0 Flash", api_identifier: "gemini-2.0-flash", for_text: true, for_image: false },
          { name: "Gemini 2.5 Pro", api_identifier: "gemini-2.5-pro", for_text: true, for_image: false }
        ]
      },
      "Stability AI" => {
        slug: "stability",
        models: [
          { name: "SDXL 1.0", api_identifier: "stable-diffusion-xl-1024-v1-0", for_text: false, for_image: true }
        ]
      }
    }

    services.each do |service_name, config|
      service = AiService.find_or_create_by!(slug: config[:slug]) do |s|
        s.name = service_name
      end

      config[:models].each do |model_attrs|
        service.ai_models.find_or_create_by!(api_identifier: model_attrs[:api_identifier]) do |m|
          m.name = model_attrs[:name]
          m.for_text = model_attrs[:for_text]
          m.for_image = model_attrs[:for_image]
        end
      end
    end
  end

  def down
    AiModel.delete_all
    AiService.delete_all
  end
end
