class AdMergeService
  class Error < StandardError; end

  def initialize(ad, audience_ids: nil, rejection_context: {})
    @ad = ad
    @audience_ids = audience_ids
    @rejection_context = rejection_context # { audience_id_string => rejection_comment }
  end

  def call
    account = @ad.client.account
    ai_key = account.ai_keys.includes(:ai_service).find_by!(ai_service_id: @ad.ai_service_id)
    ai_model = @ad.ai_model
    campaign = @ad.campaign

    text_layers = @ad.parsed_layers.select { |l| l["type"] == "text" }
    audiences = @audience_ids ? @ad.audiences.where(id: @audience_ids) : @ad.audiences

    raise Error, "No text layers found in ad" if text_layers.empty?
    raise Error, "No audiences to process" if audiences.empty?

    audiences.each do |audience|
      next if @ad.ad_versions.where(audience: audience, state: :active).exists?

      rejection_comment = @rejection_context[audience.id.to_s]
      messages = build_messages(text_layers, audience, rejection_comment, campaign: campaign)
      result = call_provider(ai_key: ai_key, model: ai_model.api_identifier, messages: messages)
      log_ai_call(account, ai_key, ai_model, messages, result)

      content = result[:content]
      raise Error, "Empty response from AI" if content.blank?

      parsed = parse_response(content)
      attach_to_version(parsed, audience)
    end
  end

  private

  def build_messages(text_layers, audience, rejection_comment, campaign: nil)
    [
      { role: "system", content: build_system_prompt },
      { role: "user", content: build_user_prompt(text_layers, audience, rejection_comment, campaign: campaign) }
    ]
  end

  def build_system_prompt
    <<~PROMPT
      You are an expert advertising copywriter. You will receive a list of text layers from an ad creative, a target audience, and optional campaign context.

      Your task is to rewrite each text layer's content to be specifically tailored for that audience while maintaining the visual intent and layout of the ad.

      You MUST respond with valid JSON mapping each layer ID to its rewritten value:
      {
        "<layer_id>": "rewritten copy for this audience"
      }

      Rules:
      - Rewrite every text layer listed
      - Keep the rewritten text approximately the same length as the original (ads have fixed layout space)
      - Maintain the same tone and energy level as the original ad
      - Use the audience name and details to inform word choices and messaging angle
      - When campaign context is provided, align copy with campaign goals
      - When a prompt/context is provided, treat it as the primary instruction
      - When a rejection comment is provided, specifically address that feedback
    PROMPT
  end

  def build_user_prompt(text_layers, audience, rejection_comment, campaign: nil)
    layer_list = text_layers.map { |l|
      "- Layer ID: #{l['id']}, Content: \"#{l['content']}\""
    }.join("\n")

    sections = []
    sections << <<~SECTION
      ## Ad Text Layers
      #{layer_list}

      ## Target Audience
      Name: #{audience.name}
      #{audience.details.present? ? "Description: #{audience.details}" : ""}
    SECTION

    if @ad.nlp_prompt.present?
      sections << "## Ad Context / Instructions\n#{@ad.nlp_prompt}"
    end

    if campaign&.ai_summary.present?
      sections << "## Campaign Summary\n#{campaign.ai_summary}"
    elsif campaign&.description.present?
      sections << "## Campaign\n#{campaign.name}: #{campaign.description}"
    end

    if rejection_comment.present?
      sections << "## Previous Version Rejection Feedback\n" \
                  "The previous version was rejected with this feedback: \"#{rejection_comment}\"\n" \
                  "Please address this feedback in the new version."
    end

    sections << "Respond with JSON only — a flat object mapping layer IDs to rewritten text values."
    sections.join("\n\n")
  end

  def call_provider(ai_key:, model:, messages:)
    AiProviders::Factory.for_text(ai_key).complete(
      model: model,
      messages: messages,
      temperature: 0.7,
      json_mode: true
    )
  rescue AiProviders::Base::Error => e
    raise Error, e.message
  end

  def log_ai_call(account, ai_key, ai_model, messages, result)
    AiLog.create!(
      account: account,
      call_type: :ad,
      ai_service_id: ai_key.ai_service_id,
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
    parsed = JSON.parse(json_string)
    raise Error, "Expected a JSON object with layer IDs as keys" unless parsed.is_a?(Hash)
    parsed
  rescue JSON::ParserError => e
    raise Error, "Failed to parse AI response: #{e.message}"
  end

  def attach_to_version(layers_data, audience)
    version = @ad.ad_versions
                  .where(audience: audience, state: :generating)
                  .order(version_number: :desc)
                  .first

    layer_ids = @ad.parsed_layers.map { |l| l["id"] }.to_set

    if version
      AdVersion.transaction do
        generated = layers_data.each_with_object([]) do |(layer_id, new_text), arr|
          next unless layer_ids.include?(layer_id)
          original = @ad.parsed_layers.find { |l| l["id"] == layer_id }
          arr << { "id" => layer_id, "content" => new_text, "original_content" => original&.dig("content") }
        end
        version.update!(generated_layers: generated, state: :active)
      end
    else
      AdVersion.transaction do
        generated = layers_data.each_with_object([]) do |(layer_id, new_text), arr|
          next unless layer_ids.include?(layer_id)
          original = @ad.parsed_layers.find { |l| l["id"] == layer_id }
          arr << { "id" => layer_id, "content" => new_text, "original_content" => original&.dig("content") }
        end
        @ad.ad_versions.create!(
          audience: audience,
          version_number: 1,
          state: :active,
          ai_service_id: @ad.ai_service_id,
          ai_model_id: @ad.ai_model_id,
          generated_layers: generated
        )
      end
    end
  end
end
