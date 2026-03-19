class AiMergeService
  class Error < StandardError; end

  def initialize(merge, audience_ids: nil, rejection_context: {})
    @merge = merge
    @audience_ids = audience_ids
    @rejection_context = rejection_context # { audience_id_string => rejection_comment }
  end

  def call
    template = @merge.email_template
    account = template.project.account
    ai_key = account.ai_keys.find_by!(ai_service_id: @merge.ai_service_id)
    ai_model = @merge.ai_model

    variables = template.template_variables.where(variable_type: "text").order(:position)
    audiences = @audience_ids ? @merge.audiences.where(id: @audience_ids) : @merge.audiences

    raise Error, "No text variables found in template" if variables.empty?
    raise Error, "No audiences to process" if audiences.empty?

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
                                brand_profile: brand_profile, campaign: campaign)
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

  def build_messages(template_html, variables, audience, rejection_comment, brand_profile: nil, campaign: nil)
    [
      { role: "system", content: build_system_prompt },
      { role: "user", content: build_user_prompt(template_html, variables, audience, rejection_comment,
                                                  brand_profile: brand_profile, campaign: campaign) }
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

  def build_system_prompt
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
      - Do not include HTML tags unless the original default value contains them
      - Use the audience name and details to inform tone and word choices
      - When a brand profile is provided, respect its tone rules, vocabulary constraints, and voice guidelines
      - When a campaign summary is provided, align the copy with the campaign's goals and messaging
      - When an email reference documents summary is provided, use it to inform facts, data, and specific details in the copy
      - When merge context is provided, treat it as the most specific instruction and prioritise it
    PROMPT
  end

  def build_user_prompt(template_html, variables, audience, rejection_comment, brand_profile: nil, campaign: nil)
    var_list = variables.map { |v|
      "- Variable ID: #{v.id}, Name: \"#{v.name}\", Default Value: \"#{v.default_value}\""
    }.join("\n")

    details = audience.details.present? ? ", Details: \"#{audience.details}\"" : ""

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
      #{rejection_section}
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
