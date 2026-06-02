# frozen_string_literal: true

module AiProviders
  class Openai < Base
    def complete(model:, messages:, temperature: 0.7, json_mode: false)
      client = ::OpenAI::Client.new(access_token: @api_key)
      params = { model: model, messages: normalize_messages(messages), temperature: temperature }
      params[:response_format] = { type: "json_object" } if json_mode

      with_retries(service_name: "OpenAI") do
        begin
          raw = client.chat(parameters: params)
          content = raw.dig("choices", 0, "message", "content")
          raise Error, "Empty response from OpenAI" if content.blank?

          usage = raw["usage"] || {}
          {
            content: content,
            prompt_tokens: usage["prompt_tokens"],
            completion_tokens: usage["completion_tokens"],
            total_tokens: usage["total_tokens"]
          }
        rescue Faraday::TooManyRequestsError => e
          retry_after = e.response_headers&.[]("retry-after")
          raise RateLimitError.new(retry_after)
        end
      end
    end

    private

    def normalize_messages(messages)
      messages.map do |m|
        next m unless m[:content].is_a?(Array)
        content = m[:content].map do |part|
          if part[:type] == "image_base64"
            { type: "image_url", image_url: { url: "data:#{part[:media_type]};base64,#{part[:data]}" } }
          else
            part
          end
        end
        m.merge(content: content)
      end
    end

    public

    def generate_image(model:, prompt:, size: "1024x1024", quality: "standard", **_opts)
      client = ::OpenAI::Client.new(access_token: @api_key)

      with_retries(service_name: "OpenAI") do
        begin
          raw = client.images.generate(
            parameters: { model: model, prompt: prompt, n: 1, size: size, quality: quality, response_format: "b64_json" }
          )
          b64 = raw.dig("data", 0, "b64_json")
          raise Error, "Empty image response from OpenAI" if b64.blank?

          { images: [ { data: b64, mime_type: "image/png" } ] }
        rescue Faraday::TooManyRequestsError => e
          retry_after = e.response_headers&.[]("retry-after")
          raise RateLimitError.new(retry_after)
        end
      end
    end
  end
end
