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

    audiences.each do |audience|
      # Skip if already completed (handles job retries — don't re-process audiences
      # that succeeded before a failure on a later audience)
      next if @merge.merge_versions.where(audience: audience, state: :active).exists?

      rejection_comment = @rejection_context[audience.id.to_s]

      response = call_openai(
        api_key: ai_key.api_key,
        model: ai_model.api_identifier,
        template_html: template.raw_source_html,
        variables: variables,
        audience: audience,
        rejection_comment: rejection_comment
      )

      parsed = parse_response(response)
      attach_to_version(parsed, audience, variables)
    end
  end

  private

  MAX_RETRIES = 5

  def call_openai(api_key:, model:, template_html:, variables:, audience:, rejection_comment: nil)
    client = OpenAI::Client.new(access_token: api_key)
    attempts = 0

    begin
      attempts += 1
      response = client.chat(
        parameters: {
          model: model,
          messages: [
            { role: "system", content: build_system_prompt },
            { role: "user", content: build_user_prompt(template_html, variables, audience, rejection_comment) }
          ],
          response_format: { type: "json_object" },
          temperature: 0.7
        }
      )

      content = response.dig("choices", 0, "message", "content")
      raise Error, "Empty response from OpenAI" if content.blank?
      content
    rescue Faraday::TooManyRequestsError => e
      raise Error, "OpenAI rate limit exceeded after #{MAX_RETRIES} retries" if attempts > MAX_RETRIES
      # Use Retry-After header if present, otherwise exponential backoff (10, 20, 40, 80, 160s)
      wait = e.response_headers&.[]("retry-after")&.to_f
      wait = 10 * (2**(attempts - 1)) if wait.nil? || wait <= 0
      Rails.logger.info("OpenAI rate limit hit for audience #{audience.name}, waiting #{wait}s (attempt #{attempts})")
      sleep(wait)
      retry
    end
  end

  def build_system_prompt
    <<~PROMPT
      You are an expert email copywriter. You will receive an email template with variable placeholders and a target audience.

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
    PROMPT
  end

  def build_user_prompt(template_html, variables, audience, rejection_comment)
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

    <<~PROMPT
      ## Email Template HTML
      ```html
      #{template_html}
      ```

      ## Text Variables to Rewrite
      #{var_list}

      ## Target Audience
      Name: #{audience.name}#{details}
      #{rejection_section}
      Respond with JSON only — a flat object mapping variable IDs to rewritten values.
    PROMPT
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
    version = @merge.merge_versions
                    .where(audience: audience, state: :generating)
                    .order(version_number: :desc)
                    .first

    if version
      MergeVersionVariable.transaction do
        vars_data.each do |variable_id, value|
          next unless variable_ids.include?(variable_id)
          version.merge_version_variables.create!(template_variable_id: variable_id, value: value)
        end
        version.update!(state: :active)
      end
    else
      MergeVersion.transaction do
        new_version = @merge.merge_versions.create!(
          audience: audience,
          version_number: 1,
          state: :active,
          ai_service_id: @merge.ai_service_id,
          ai_model_id: @merge.ai_model_id
        )
        vars_data.each do |variable_id, value|
          next unless variable_ids.include?(variable_id)
          new_version.merge_version_variables.create!(template_variable_id: variable_id, value: value)
        end
      end
    end
  end
end
