module AiProviders
  module Factory
    TEXT_PROVIDERS = {
      "openai"    => AiProviders::Openai,
      "anthropic" => AiProviders::Anthropic,
      "google"    => AiProviders::Gemini
    }.freeze

    IMAGE_PROVIDERS = {
      "openai"    => AiProviders::Openai,
      "stability" => AiProviders::StabilityAi
    }.freeze

    def self.for_text(ai_key)
      slug = ai_key.ai_service.slug
      klass = TEXT_PROVIDERS[slug] or raise AiProviders::Base::Error, "Unsupported text AI service: #{slug}"
      klass.new(api_key: ai_key.api_key)
    end

    def self.for_image(ai_key)
      slug = ai_key.ai_service.slug
      klass = IMAGE_PROVIDERS[slug] or raise AiProviders::Base::Error, "Unsupported image AI service: #{slug}"
      klass.new(api_key: ai_key.api_key)
    end
  end
end
