class AudienceSummaryService
  class Error < StandardError; end

  SUMMARY_FIELDS = %w[
    executive_summary
    demographics_and_financial_capacity
    lapse_diagnosis
    relationship_state_and_pre_lapse_indicators
    motivational_drivers_and_messaging_framework
    strategic_reactivation_and_upgrade_cadence
    creative_and_imagery_rules
    risk_scoring_model
    prohibited_patterns
    success_indicators_and_macro_trends
  ].freeze

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are an audience intelligence analyst. You will receive structured profile data about a marketing audience
    along with any supporting documents and existing summary fields.

    Your task is to produce a comprehensive audience intelligence report as a JSON object with exactly these keys:

    - executive_summary: A dense overview of who this audience is, their value, and how to approach them (200-400 words)
    - demographics_and_financial_capacity: Demographic profile, income/spending patterns, financial behaviors
    - lapse_diagnosis: Why this audience lapses, warning signs, and re-engagement windows
    - relationship_state_and_pre_lapse_indicators: Current relationship health and early signals of disengagement
    - motivational_drivers_and_messaging_framework: What motivates action, preferred messaging angles and tone
    - strategic_reactivation_and_upgrade_cadence: Timing and strategy for reactivation, upsell, and lifecycle progression
    - creative_and_imagery_rules: Visual style guidelines, imagery that resonates vs. repels
    - risk_scoring_model: Framework for scoring engagement risk on a 1-100 scale with tier definitions
    - prohibited_patterns: Language, framing, and creative approaches to avoid
    - success_indicators_and_macro_trends: KPIs to track and broader market trends affecting this audience

    Each field should be detailed and actionable (150-400 words each). Use clear section headings within each field.
    If existing summary values are provided, incorporate and improve upon them.

    Respond with ONLY a valid JSON object. No markdown, no code fences, no explanation outside the JSON.
  PROMPT

  def initialize(audience)
    @audience = audience
  end

  def call
    ai_service, ai_model = find_ai_credentials
    raise Error, "No text-capable AI service configured" unless ai_service && ai_model

    document_texts = collect_document_texts
    prompt = build_user_prompt(document_texts)

    messages = [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: prompt }
    ]

    result = AiProviders::Factory.for_text(ai_service).complete(
      model: ai_model.api_identifier,
      messages: messages,
      temperature: 0.3,
      json_mode: true
    )

    parsed = parse_response(result[:content])
    raise Error, "Empty response from AI" if parsed.empty?

    log_ai_call(ai_model, messages, result)

    parsed
  end

  private

  def parse_response(content)
    raise Error, "Blank AI response" if content.blank?

    json = JSON.parse(content)
    SUMMARY_FIELDS.each_with_object({}) do |key, hash|
      hash[key] = json[key] if json[key].present?
    end
  rescue JSON::ParserError => e
    raise Error, "Failed to parse AI response as JSON: #{e.message}"
  end

  def log_ai_call(ai_model, messages, result)
    AiLog.create!(
      account: @audience.client.account,
      call_type: :audience_summary,
      ai_service_id: ai_model.ai_service_id,
      ai_model: ai_model,
      loggable: @audience,
      prompt: messages.to_json,
      response: result[:content],
      prompt_tokens: result[:prompt_tokens],
      completion_tokens: result[:completion_tokens],
      total_tokens: result[:total_tokens]
    )
  rescue StandardError => e
    Rails.logger.error("AiLog failed to save for audience #{@audience.id}: #{e.message}")
  end

  def find_ai_credentials
    AiKey.includes(ai_service: :ai_models).find_each do |key|
      model = key.ai_service.ai_models.find { |m| m.for_text? }
      return [ key.ai_service, model ] if model
    end
    [ nil, nil ]
  end

  def collect_document_texts
    @audience.assets.map do |asset|
      text = asset.content_text || extract_and_cache_text(asset)
      { name: asset.display_name || asset.name, text: text }
    end
  end

  def extract_and_cache_text(asset)
    return nil unless asset.file.attached?

    text = begin
      content_type = asset.file.blob.content_type
      filename = asset.file.blob.filename.to_s

      if content_type == "application/pdf"
        extract_pdf(asset)
      elsif content_type.include?("wordprocessingml") || filename.end_with?(".docx")
        extract_docx(asset)
      else
        nil
      end
    rescue StandardError => e
      Rails.logger.warn("Text extraction failed for asset #{asset.id}: #{e.message}")
      nil
    end

    asset.update_column(:content_text, text) if text.present?
    text
  end

  def extract_pdf(asset)
    asset.file.open do |file|
      reader = PDF::Reader.new(file.path)
      reader.pages.map(&:text).join("\n").strip.truncate(60_000)
    end
  end

  def extract_docx(asset)
    asset.file.open do |file|
      Zip::File.open(file.path) do |zip|
        entry = zip.glob("word/document.xml").first
        return nil unless entry
        xml = entry.get_input_stream.read
        parsed = Nokogiri::XML(xml)
        parsed.remove_namespaces!
        parsed.css("t").map(&:text).join(" ").strip.truncate(60_000)
      end
    end
  end

  def build_user_prompt(document_texts)
    sections = []

    sections << "## Audience Name\n#{@audience.name}"

    # Profile fields
    add_field(sections, "Client URL", @audience.client_url)
    add_field(sections, "Industry", format_with_other(@audience.industry, @audience.industry_other))
    add_field(sections, "General Insights", @audience.general_insights)
    add_field(sections, "Supporting Sites", @audience.supporting_sites&.reject(&:blank?)&.join(", "))
    add_field(sections, "Interaction Recency", format_with_other(@audience.interaction_recency, @audience.interaction_recency_other))
    add_field(sections, "Purchase Cadence", format_with_other(@audience.purchase_cadence, @audience.purchase_cadence_other))
    add_field(sections, "Relationship Status", @audience.relationship_status)
    add_field(sections, "Outcomes That Matter", format_array_with_other(@audience.outcomes_that_matter, @audience.outcomes_that_matter_other))
    add_field(sections, "Primary Action", format_with_other(@audience.primary_action, @audience.primary_action_other))
    add_field(sections, "Order Value Band", format_with_other(@audience.order_value_band, @audience.order_value_band_other))
    add_field(sections, "Top Purchase Drivers", format_array_with_other(@audience.top_purchase_drivers, @audience.top_purchase_drivers_other))
    add_field(sections, "Promotion Sensitivity", format_with_other(@audience.promotion_sensitivity, @audience.promotion_sensitivity_other))
    add_field(sections, "Action Prevention Factors", format_array_with_other(@audience.action_prevention_factors, @audience.action_prevention_factors_other))
    add_field(sections, "Checkout Friction Points", format_array_with_other(@audience.checkout_friction_points, @audience.checkout_friction_points_other))
    add_field(sections, "Communication Frequency", format_with_other(@audience.communication_frequency, @audience.communication_frequency_other))
    add_field(sections, "Communication Channels", format_array_with_other(@audience.communication_channels, @audience.communication_channels_other))
    add_field(sections, "Lifecycle Messages", format_array_with_other(@audience.lifecycle_messages, @audience.lifecycle_messages_other))
    add_field(sections, "Product Visuals Impact", @audience.product_visuals_impact)
    add_field(sections, "Product Categories/Themes", @audience.product_categories_themes)

    # Existing summary fields (for re-generation)
    existing = SUMMARY_FIELDS.filter_map do |key|
      value = @audience.send(key)
      "### #{key.titleize}\n#{value}" if value.present?
    end
    if existing.any?
      sections << "## Existing Summary (improve upon these)\n#{existing.join("\n\n")}"
    end

    # Documents
    document_texts.each do |doc|
      if doc[:text].present?
        sections << "## Document: #{doc[:name]}\n#{doc[:text].truncate(15_000)}"
      else
        sections << "## Document: #{doc[:name]}\n(Binary file — text could not be extracted)"
      end
    end

    sections.join("\n\n")
  end

  def add_field(sections, label, value)
    sections << "## #{label}\n#{value}" if value.present?
  end

  def format_with_other(value, other)
    return nil if value.blank?
    value == "Other" && other.present? ? "Other: #{other}" : value
  end

  def format_array_with_other(values, other)
    return nil if values.blank?
    items = values.reject(&:blank?)
    return nil if items.empty?
    if items.include?("Other") && other.present?
      items = items.map { |v| v == "Other" ? "Other: #{other}" : v }
    end
    items.join(", ")
  end
end
