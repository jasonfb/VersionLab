class AdAiClassifyService
  class Error < StandardError; end

  ROLES = %w[headline subhead body cta logo background decoration].freeze

  def initialize(ad)
    @ad = ad
  end

  # Calls the AI to (1) assign a role to each text layer and (2) detect
  # continuation chains where a sentence is split across multiple text
  # fragments. Updates `ad.classified_layers` in place and returns it.
  def call
    layers = @ad.classified_layers.presence || @ad.parsed_layers
    raise Error, "Ad has no layers to classify" if layers.blank?

    text_layers = layers.select { |l| l["type"] == "text" && l["content"].to_s.strip.present? }
    raise Error, "Ad has no text layers to classify" if text_layers.empty?

    account = @ad.client.account
    ai_model = resolve_ai_model
    raise Error, "No AI service is configured. Add an API key in admin settings first." unless ai_model

    messages = build_messages(text_layers)
    result = call_provider(ai_service_id: ai_model.ai_service_id, model: ai_model.api_identifier, messages: messages)
    log_ai_call(account, ai_model, messages, result)

    parsed = parse_response(result[:content])
    apply_to_layers!(layers, parsed)

    @ad.update!(classified_layers: layers)
    layers
  end

  private

  # Use the ad's configured ai_model if it has one (and a key exists for its
  # service); otherwise fall back to the first available AiModel whose service
  # has an AiKey. Classify happens during setup, before the user has picked
  # an AI provider for the ad itself.
  def resolve_ai_model
    if @ad.ai_model && AiKey.exists?(ai_service_id: @ad.ai_model.ai_service_id)
      return @ad.ai_model
    end

    service_ids_with_keys = AiKey.pluck(:ai_service_id)
    return nil if service_ids_with_keys.empty?

    AiModel.where(ai_service_id: service_ids_with_keys).order(:created_at).first
  end

  def build_messages(text_layers)
    [
      { role: "system", content: build_system_prompt },
      { role: "user", content: build_user_prompt(text_layers) }
    ]
  end

  def build_system_prompt
    <<~PROMPT
      You are an expert at analyzing the structure of advertising creative.

      You will receive a list of text fragments extracted from an ad, each with an id, content, font size, and approximate (x, y) position. Your job is two things:

      1. ROLE CLASSIFICATION — assign exactly one role to each fragment from this set:
         - headline    : the primary attention-grabbing line, usually the largest text
         - subhead     : secondary supporting line, smaller than headline
         - body        : descriptive sentences and supporting copy
         - cta         : a call to action like "Shop Now", "Learn More", "Discover the Collection"
         - logo        : a brand mark expressed as text (e.g. "CLIO", "ATELIER")
         - decoration  : ornamental text such as taglines, dingbats, or decorative dates

      2. CONTINUATION DETECTION — identify when a single sentence has been split across multiple text fragments because of line wrapping in the source design. The classic case: "Timeless luxury pieces crafted for those who define" on line 1 and "their own elegance." on line 2 — these are two fragments of one sentence and should be linked. For each fragment that is a CONTINUATION of the previous one, set `continuation_of` to the id of the fragment it continues from. Continuation chains can be longer than two — fragment 3 continues from 2, which continues from 1.

      Rules for continuation detection:
      - Only link fragments with the SAME role (typically body or subhead)
      - Only link if the previous fragment does NOT end with a sentence terminator (. ! ? :)
      - Only link if the fragments share the same approximate font styling and are vertically stacked
      - The CTA, logo, and headline roles should almost never be continuations
      - When in doubt, do NOT link — false positives are worse than missed links

      You MUST respond with valid JSON in this exact shape:
      {
        "layers": [
          { "id": "<layer_id>", "role": "<role>", "continuation_of": "<previous_layer_id_or_null>" },
          ...
        ]
      }

      Include every input fragment in the response. Use null (not the string "null") when there is no continuation.
    PROMPT
  end

  def build_user_prompt(text_layers)
    lines = text_layers.map { |l|
      parts = []
      parts << "id: #{l['id']}"
      parts << %(content: "#{l['content']}")
      parts << "font_size: #{l['font_size']}" if l["font_size"].present?
      parts << "x: #{l['x']}" if l["x"].present?
      parts << "y: #{l['y']}" if l["y"].present?
      "- { #{parts.join(', ')} }"
    }.join("\n")

    <<~PROMPT
      Analyze these text fragments and respond with the JSON described in the system prompt.

      Fragments (in document order):
      #{lines}
    PROMPT
  end

  def call_provider(ai_service_id:, model:, messages:)
    AiProviders::Factory.for_text(AiService.find(ai_service_id)).complete(
      model: model,
      messages: messages,
      temperature: 0.2,
      json_mode: true
    )
  rescue AiProviders::Base::Error => e
    raise Error, e.message
  end

  def log_ai_call(account, ai_model, messages, result)
    AiLog.create!(
      account: account,
      call_type: :ad,
      ai_service_id: ai_model.ai_service_id,
      ai_model: ai_model,
      loggable: @ad,
      prompt: messages.to_json,
      response: result[:content],
      prompt_tokens: result[:prompt_tokens],
      completion_tokens: result[:completion_tokens],
      total_tokens: result[:total_tokens]
    )
  rescue StandardError => e
    Rails.logger.error("AiLog failed to save for ad #{@ad.id}: #{e.message}")
  end

  def parse_response(json_string)
    raise Error, "Empty response from AI" if json_string.blank?
    parsed = JSON.parse(json_string)
    layers = parsed.is_a?(Hash) ? parsed["layers"] : nil
    raise Error, "Expected a JSON object with a 'layers' array" unless layers.is_a?(Array)
    layers
  rescue JSON::ParserError => e
    raise Error, "Failed to parse AI response: #{e.message}"
  end

  # Mutate the live layers array, applying AI suggestions only to text layers
  # whose ids match the response. Non-text layers are left as-is.
  def apply_to_layers!(layers, ai_layers)
    by_id = ai_layers.index_by { |l| l["id"] }
    valid_ids = layers.map { |l| l["id"] }.to_set

    layers.each do |layer|
      next unless layer["type"] == "text"
      suggestion = by_id[layer["id"]]
      next unless suggestion

      role = suggestion["role"].to_s
      layer["role"] = role if ROLES.include?(role)

      cont = suggestion["continuation_of"]
      cont = nil if cont.is_a?(String) && cont.strip.downcase.in?(["", "null"])
      if cont.present? && valid_ids.include?(cont) && cont != layer["id"]
        layer["continuation_of"] = cont
      else
        layer.delete("continuation_of")
      end

      layer["confidence"] = 0.95
    end

    layers
  end
end
