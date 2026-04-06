require "net/http"

module AiProviders
  class Perplexity < Base
    API_URI = URI("https://api.perplexity.ai/chat/completions").freeze

    def complete(model:, messages:, temperature: 0.7, json_mode: false)
      chat_messages = messages.map { |m| { role: m[:role].to_s, content: m[:content] } }

      body = {
        model: model,
        messages: chat_messages,
        temperature: temperature
      }

      if json_mode
        system_msg = chat_messages.find { |m| m[:role] == "system" }
        if system_msg
          system_msg[:content] = "#{system_msg[:content]}\n\nRespond with valid JSON only."
        else
          chat_messages.unshift({ role: "system", content: "Respond with valid JSON only." })
        end
      end

      with_retries(service_name: "Perplexity") do
        response = http_post(API_URI, body, request_headers)

        if response.code == "429"
          raise RateLimitError.new(response["retry-after"])
        end

        unless response.code.start_with?("2")
          raise Error, "Perplexity API error #{response.code}: #{response.body.truncate(500)}"
        end

        raw = JSON.parse(response.body)
        choice = raw.dig("choices", 0, "message", "content")
        raise Error, "Empty response from Perplexity" if choice.blank?

        usage = raw["usage"] || {}
        {
          content: choice,
          prompt_tokens: usage["prompt_tokens"],
          completion_tokens: usage["completion_tokens"],
          total_tokens: usage["total_tokens"] || (usage["prompt_tokens"].to_i + usage["completion_tokens"].to_i)
        }
      end
    end

    private

    def request_headers
      {
        "Authorization" => "Bearer #{@api_key}"
      }
    end
  end
end
