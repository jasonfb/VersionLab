require "net/http"

module AiProviders
  class Anthropic < Base
    API_URI = URI("https://api.anthropic.com/v1/messages").freeze
    API_VERSION = "2023-06-01"
    MAX_TOKENS = 4096

    def complete(model:, messages:, temperature: 0.7, json_mode: false)
      system_content = messages.find { |m| m[:role].to_s == "system" }&.dig(:content)
      chat_messages  = messages
        .reject { |m| m[:role].to_s == "system" }
        .map { |m| { role: m[:role].to_s, content: m[:content] } }

      body = {
        model: model,
        max_tokens: MAX_TOKENS,
        messages: chat_messages,
        temperature: temperature
      }

      if system_content.present?
        # json_mode: append instruction to system prompt so Anthropic returns clean JSON
        body[:system] = json_mode ? "#{system_content}\n\nRespond with valid JSON only." : system_content
      elsif json_mode
        body[:system] = "Respond with valid JSON only."
      end

      with_retries(service_name: "Anthropic") do
        response = http_post(API_URI, body, request_headers)

        if response.code == "429"
          raise RateLimitError.new(response["retry-after"])
        end

        unless response.code.start_with?("2")
          raise Error, "Anthropic API error #{response.code}: #{response.body.truncate(500)}"
        end

        raw = JSON.parse(response.body)
        content = raw.dig("content", 0, "text")
        raise Error, "Empty response from Anthropic" if content.blank?

        usage = raw["usage"] || {}
        {
          content: content,
          prompt_tokens: usage["input_tokens"],
          completion_tokens: usage["output_tokens"],
          total_tokens: usage["input_tokens"].to_i + usage["output_tokens"].to_i
        }
      end
    end

    private

    def request_headers
      {
        "x-api-key"         => @api_key,
        "anthropic-version" => API_VERSION
      }
    end
  end
end
