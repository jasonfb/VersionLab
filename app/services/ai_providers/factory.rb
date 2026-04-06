module AiProviders
  module Factory
    TEXT_PROVIDERS = {
      "openai"      => AiProviders::Openai,
      "anthropic"   => AiProviders::Anthropic,
      "google"      => AiProviders::Gemini,
      "perplexity"  => AiProviders::Perplexity
    }.freeze

    IMAGE_PROVIDERS = {
      "openai"    => AiProviders::Openai,
      "stability" => AiProviders::StabilityAi
    }.freeze

    def self.for_text(ai_service)
      ai_key = resolve_key(ai_service)
      slug = ai_key.ai_service.slug
      klass = TEXT_PROVIDERS[slug] or raise AiProviders::Base::Error, "Unsupported text AI service: #{slug}"
      klass.new(api_key: ai_key.api_key)
    end

    def self.for_image(ai_service)
      ai_key = resolve_key(ai_service)
      slug = ai_key.ai_service.slug
      klass = IMAGE_PROVIDERS[slug] or raise AiProviders::Base::Error, "Unsupported image AI service: #{slug}"
      klass.new(api_key: ai_key.api_key)
    end

    def self.resolve_key(ai_service)
      service = ai_service.is_a?(AiService) ? ai_service : AiService.find(ai_service)
      service.ai_key or raise AiProviders::Base::Error, "No API key configured for #{service.name}"
    end
    private_class_method :resolve_key
  end
end
