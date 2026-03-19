class AiMergeService
  class Error < StandardError; end

  def initialize(merge, audience_ids: nil, rejection_context: {})
    @merge = merge
    @audience_ids = audience_ids
    @rejection_context = rejection_context # { audience_id_string => rejection_comment }
  end

  def call
    template = @merge.email_template
    account = template.client.account
    ai_key = account.ai_keys.find_by!(ai_service_id: @merge.ai_service_id)
    ai_model = @merge.ai_model

    variables = template.template_variables.where(variable_type: "text").order(:position)
    audiences = @audience_ids ? @merge.audiences.where(id: @audience_ids) : @merge.audiences

    raise Error, "No text variables found in template" if variables.empty?
    raise Error, "No audiences to process" if audiences.empty?

    autolink_settings = @merge.email_section_autolink_settings
                              .where.not(autolink_mode: "none")
                              .includes(email_template_section: :template_variables)

    brand_profile = @merge.client.brand_profile&.tap do |bp|
      bp.association(:organization_type).load_target
      bp.association(:industry).load_target
      bp.association(:tone_rules).load_target
      bp.association(:primary_audiences).load_target
      bp.association(:geographies).load_target
    end
    campaign = @merge.campaign

    audiences.each do |audience|
      # Skip if already completed (handles job retries — don't re-process audiences
      # that succeeded before a failure on a later audience)
      next if @merge.email_versions.where(audience: audience, state: :active).exists?

      rejection_comment = @rejection_context[audience.id.to_s]

      messages = build_messages(template.raw_source_html, variables, audience, rejection_comment,
                                brand_profile: brand_profile, campaign: campaign,
                                autolink_settings: autolink_settings)
      raw_response = call_openai(
        api_key: ai_key.api_key,
        model: ai_model.api_identifier,
        messages: messages
      )

      log_ai_call(account, ai_key, ai_model, messages, raw_response)

      content = raw_response.dig("choices", 0, "message", "content")
      raise Error, "Empty response from OpenAI" if content.blank?

      parsed = parse_response(content)
      attach_to_version(parsed, audience, variables)
    end
  end

  private

  MAX_RETRIES = 5

  def build_messages(template_html, variables, audience, rejection_comment, brand_profile: nil, campaign: nil, autolink_settings: [])
    [
      { role: "system", content: build_system_prompt(has_autolinking: autolink_settings.any?) },
      { role: "user", content: build_user_prompt(template_html, variables, audience, rejection_comment,
                                                  brand_profile: brand_profile, campaign: campaign,
                                                  autolink_settings: autolink_settings) }
    ]
  end

  def call_openai(api_key:, model:, messages:)
    client = OpenAI::Client.new(access_token: api_key)
    attempts = 0

    begin
      attempts += 1
      client.chat(
        parameters: {
          model: model,
          messages: messages,
          response_format: { type: "json_object" },
          temperature: 0.7
        }
      )
    rescue Faraday::TooManyRequestsError => e
      raise Error, "OpenAI rate limit exceeded after #{MAX_RETRIES} retries" if attempts > MAX_RETRIES
      # Use Retry-After header if present, otherwise exponential backoff (10, 20, 40, 80, 160s)
      wait = e.response_headers&.[]("retry-after")&.to_f
      wait = 10 * (2**(attempts - 1)) if wait.nil? || wait <= 0
      Rails.logger.info("OpenAI rate limit hit, waiting #{wait}s (attempt #{attempts})")
      sleep(wait)
      retry
    end
  end

  def log_ai_call(account, ai_key, ai_model, messages, raw_response)
    usage = raw_response["usage"] || {}
    content = raw_response.dig("choices", 0, "message", "content")
    AiLog.create!(
      account: account,
      call_type: :email,
      ai_service_id: ai_key.ai_service_id,
      ai_model: ai_model,
      loggable: @merge,
      prompt: messages.to_json,
      response: content,
      prompt_tokens: usage["prompt_tokens"],
      completion_tokens: usage["completion_tokens"],
      total_tokens: usage["total_tokens"]
    )
  rescue StandardError => e
    Rails.logger.error("AiLog failed to save for email #{@merge.id}: #{e.message}")
  end

  def build_system_prompt(has_autolinking: false)
    autolinking_rule = has_autolinking ? "\n      - When autolinking instructions are provided for specific variables, you MAY wrap relevant text phrases in HTML anchor tags (<a href=\"...\">text</a>). This is an exception to the no-HTML rule. Only add links to variables explicitly listed in the autolinking instructions." : ""

    <<~PROMPT
      You are an expert email copywriter. You will receive an email template with variable placeholders, a target audience, and optional context including a brand profile and campaign summary.

      Your task is to rewrite each text variable's content to be specifically tailored for that audience.

      You MUST respond with valid JSON mapping each variable ID to its rewritten value:
      {
        "<variable_id>": "rewritten copy for this audience"
      }

      Rules:
      - Rewrite every text variable listed
      - Keep approximate length similar to the original default value
      - Do not include HTML tags unless the original default value contains them#{autolinking_rule}
      - Use the audience name and details to inform tone and word choices
      - When a brand profile is provided, respect its tone rules, vocabulary constraints, and voice guidelines
      - When a campaign summary is provided, align the copy with the campaign's goals and messaging
      - When an email reference documents summary is provided, use it to inform facts, data, and specific details in the copy
      - When merge context is provided, treat it as the most specific instruction and prioritise it
    PROMPT
  end

  def build_user_prompt(template_html, variables, audience, rejection_comment, brand_profile: nil, campaign: nil, autolink_settings: [])
    var_list = variables.map { |v|
      "- Variable ID: #{v.id}, Name: \"#{v.name}\", Default Value: \"#{v.default_value}\""
    }.join("\n")

    details = audience.details.present? ? "\nDescription: #{audience.details}" : ""

    # TODO: Prompt bloat concern — each filled audience intelligence field can add hundreds of tokens.
    # With multiple audiences per email, this multiplies quickly. Consider options:
    #   1. Summarise the audience profile into a single condensed block before sending.
    #   2. Let users select which fields are "active" for prompt inclusion.
    #   3. Truncate each field to a character limit (e.g. 500 chars) before injecting.
    audience_intelligence = build_audience_intelligence_section(audience)

    rejection_section = if rejection_comment.present?
      "\n## Previous Version Rejection Feedback\n" \
      "The previous version was rejected with this feedback: \"#{rejection_comment}\"\n" \
      "Please address this feedback in the new version.\n"
    else
      ""
    end

    sections = []

    sections << <<~SECTION
      ## Email Template HTML
      ```html
      #{template_html}
      ```

      ## Text Variables to Rewrite
      #{var_list}

      ## Target Audience
      Name: #{audience.name}#{details}
      #{audience_intelligence}#{rejection_section}
    SECTION

    if brand_profile.present?
      sections << build_brand_profile_section(brand_profile)
    end

    if campaign&.ai_summary.present?
      sections << "## Campaign Summary\n#{campaign.ai_summary}"
    end

    if @merge.ai_summary.present?
      sections << "## Email Reference Documents Summary\n#{@merge.ai_summary}"
    end

    if @merge.context.present?
      sections << "## Merge Context\n#{@merge.context}"
    end

    autolink_section = build_autolink_section(autolink_settings, variables)
    sections << autolink_section if autolink_section.present?

    sections << "Respond with JSON only — a flat object mapping variable IDs to rewritten values."

    sections.join("\n\n")
  end

  def build_brand_profile_section(bp)
    lines = [ "## Brand Profile" ]
    lines << "Organization: #{bp.organization_name}" if bp.organization_name.present?
    lines << "Industry: #{bp.industry.name}" if bp.industry.present?
    lines << "Organization type: #{bp.organization_type.name}" if bp.organization_type.present?
    lines << "Mission: #{bp.mission_statement}" if bp.mission_statement.present?
    lines << "Core programs: #{bp.core_programs}" if bp.core_programs.present?

    if bp.tone_rules.any?
      lines << "Tone rules: #{bp.tone_rules.map(&:name).join(", ")}"
    end
    if bp.primary_audiences.any?
      lines << "Primary audiences: #{bp.primary_audiences.map(&:name).join(", ")}"
    end
    if bp.geographies.any?
      lines << "Geographies: #{bp.geographies.map(&:name).join(", ")}"
    end
    if bp.approved_vocabulary.present?
      lines << "Approved vocabulary: #{bp.approved_vocabulary}"
    end
    if bp.blocked_vocabulary.present?
      lines << "Blocked vocabulary (do not use): #{bp.blocked_vocabulary}"
    end

    lines.join("\n")
  end

  def build_audience_intelligence_section(audience)
    fields = {
      "Executive Summary"                                    => audience.executive_summary,
      "Demographics and Financial Capacity"                  => audience.demographics_and_financial_capacity,
      "Lapse Diagnosis"                                      => audience.lapse_diagnosis,
      "Relationship State and Pre-Lapse Indicators"          => audience.relationship_state_and_pre_lapse_indicators,
      "Motivational Drivers and Messaging Framework"         => audience.motivational_drivers_and_messaging_framework,
      "Strategic Reactivation and Upgrade Cadence"           => audience.strategic_reactivation_and_upgrade_cadence,
      "Creative and Imagery Rules"                           => audience.creative_and_imagery_rules,
      "Risk Scoring Model (1-100)"                           => audience.risk_scoring_model,
      "Prohibited Patterns — Language and Framing"          => audience.prohibited_patterns,
      "Success Indicators and Macro-Trends"                  => audience.success_indicators_and_macro_trends,
    }

    present = fields.select { |_, v| v.present? }
    return "" if present.empty?

    lines = [ "\n### Audience Intelligence Profile" ]
    present.each do |label, value|
      lines << "**#{label}:** #{value}"
    end
    lines.join("\n")
  end

  def build_autolink_section(autolink_settings, variables)
    return nil if autolink_settings.empty?

    variable_ids = variables.map(&:id).to_set
    eligible_roles = %w[subheadline body]

    lines = [
      "## Autolinking Instructions",
      "",
      "For the variable IDs listed below, you may add HTML hyperlinks to create links within the copy. " \
      "Wrap relevant text phrases in anchor tags. This overrides the no-HTML rule for these variables only.",
      ""
    ]

    any_section_added = false

    autolink_settings.each do |setting|
      section = setting.email_template_section
      eligible_vars = section.template_variables.select { |v|
        variable_ids.include?(v.id) && eligible_roles.include?(v.slot_role)
      }
      next if eligible_vars.empty?

      any_section_added = true
      lines << "### #{section.name.presence || "Section #{section.position}"}"
      lines << "Variables: #{eligible_vars.map { |v| "#{v.id} (#{v.name}, role: #{v.slot_role})" }.join('; ')}"

      if setting.user_url? && setting.url.present?
        lines << "Link destination: Use this URL for all anchor tags in this section: #{setting.url}"
      else
        lines << "Link destination: Choose contextually appropriate URLs based on the copy."
      end

      lines << "Group purpose: #{setting.group_purpose}" if setting.group_purpose.present?

      style_parts = []
      style_parts << "color:#{setting.link_color}" if setting.link_color.present?
      style_parts << "text-decoration:underline" if setting.underline_links
      style_parts << "font-style:italic" if setting.italic_links
      style_parts << "font-weight:bold" if setting.bold_links

      if style_parts.any?
        lines << "Anchor tag style: Apply this style attribute to all anchor tags — style=\"#{style_parts.join(';')}\""
      end

      lines << ""
    end

    any_section_added ? lines.join("\n") : nil
  end

  def parse_response(json_string)
    parsed = JSON.parse(json_string)
    raise Error, "Expected a JSON object with variable IDs as keys" unless parsed.is_a?(Hash)
    parsed
  rescue JSON::ParserError => e
    raise Error, "Failed to parse AI response: #{e.message}"
  end

  def attach_to_version(vars_data, audience, variables)
    variable_ids = variables.pluck(:id).to_set

    # During regeneration the controller pre-creates a generating version.
    # During initial run we create the active version here.
    version = @merge.email_versions
                    .where(audience: audience, state: :generating)
                    .order(version_number: :desc)
                    .first

    if version
      EmailVersionVariable.transaction do
        vars_data.each do |variable_id, value|
          next unless variable_ids.include?(variable_id)
          version.email_version_variables.create!(template_variable_id: variable_id, value: value)
        end
        version.update!(state: :active)
      end
    else
      EmailVersion.transaction do
        new_version = @merge.email_versions.create!(
          audience: audience,
          version_number: 1,
          state: :active,
          ai_service_id: @merge.ai_service_id,
          ai_model_id: @merge.ai_model_id
        )
        vars_data.each do |variable_id, value|
          next unless variable_ids.include?(variable_id)
          new_version.email_version_variables.create!(template_variable_id: variable_id, value: value)
        end
      end
    end
  end
end
