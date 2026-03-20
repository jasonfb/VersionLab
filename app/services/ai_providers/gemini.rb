require "net/http"

module AiProviders
  class Gemini < Base
    BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models".freeze

    def complete(model:, messages:, temperature: 0.7, json_mode: false)
      system_content = messages.find { |m| m[:role].to_s == "system" }&.dig(:content)

      # Gemini uses "user"/"model" roles; map "assistant" → "model"
      contents = messages
        .reject { |m| m[:role].to_s == "system" }
        .map do |m|
          role = m[:role].to_s == "assistant" ? "model" : "user"
          { role: role, parts: [ { text: m[:content] } ] }
        end

      body = {
        contents: contents,
        generationConfig: { temperature: temperature }
      }

      body[:systemInstruction] = { parts: [ { text: system_content } ] } if system_content.present?
      body[:generationConfig][:responseMimeType] = "application/json" if json_mode

      with_retries(service_name: "Gemini") do
        uri = api_uri(model)
        response = http_post(uri, body, request_headers)

        if response.code == "429"
          raise RateLimitError.new(response["retry-after"])
        end

        unless response.code.start_with?("2")
          raise Error, "Gemini API error #{response.code}: #{response.body.truncate(500)}"
        end

        raw = JSON.parse(response.body)
        content = raw.dig("candidates", 0, "content", "parts", 0, "text")
        raise Error, "Empty response from Gemini" if content.blank?

        usage = raw["usageMetadata"] || {}
        {
          content: content,
          prompt_tokens: usage["promptTokenCount"],
          completion_tokens: usage["candidatesTokenCount"],
          total_tokens: usage["totalTokenCount"]
        }
      end
    end

    private

    def api_uri(model)
      URI("#{BASE_URL}/#{model}:generateContent?key=#{@api_key}")
    end

    def request_headers
      {}  # API key is passed as query param for Gemini
    end
  end
end
