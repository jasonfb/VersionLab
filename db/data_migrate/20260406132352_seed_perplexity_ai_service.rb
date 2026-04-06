class SeedPerplexityAiService < ActiveRecord::Migration[8.1]
  def up
    service = AiService.find_or_create_by!(slug: "perplexity") do |s|
      s.name = "Perplexity"
    end

    models = [
      { name: "Sonar", api_identifier: "sonar", for_text: true, for_image: false },
      { name: "Sonar Pro", api_identifier: "sonar-pro", for_text: true, for_image: false },
      { name: "Sonar Reasoning", api_identifier: "sonar-reasoning", for_text: true, for_image: false },
      { name: "Sonar Reasoning Pro", api_identifier: "sonar-reasoning-pro", for_text: true, for_image: false }
    ]

    models.each do |model_attrs|
      service.ai_models.find_or_create_by!(api_identifier: model_attrs[:api_identifier]) do |m|
        m.name = model_attrs[:name]
        m.for_text = model_attrs[:for_text]
        m.for_image = model_attrs[:for_image]
      end
    end
  end

  def down
    service = AiService.find_by(slug: "perplexity")
    if service
      service.ai_models.delete_all
      service.destroy
    end
  end
end
