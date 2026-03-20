require "net/http"

module AiProviders
  # Stability AI provider — image generation only.
  # Uses the Stability AI REST API v1 (stable-diffusion-xl-1024-v1-0 and similar engines).
  class StabilityAi < Base
    BASE_URL = "https://api.stability.ai/v1/generation".freeze

    # opts:
    #   cfg_scale:   Float  (default 7.0)  — how strictly to follow the prompt
    #   steps:       Integer (default 30)  — diffusion steps
    #   width:       Integer (default 1024)
    #   height:      Integer (default 1024)
    #   samples:     Integer (default 1)   — number of images to generate
    def generate_image(model:, prompt:, cfg_scale: 7.0, steps: 30, width: 1024, height: 1024, samples: 1, **_opts)
      body = {
        text_prompts: [ { text: prompt, weight: 1.0 } ],
        cfg_scale: cfg_scale,
        steps: steps,
        width: width,
        height: height,
        samples: samples
      }

      with_retries(service_name: "Stability AI") do
        uri = api_uri(model)
        response = http_post(uri, body, request_headers)

        if response.code == "429"
          raise RateLimitError.new(response["retry-after"])
        end

        unless response.code.start_with?("2")
          raise Error, "Stability AI API error #{response.code}: #{response.body.truncate(500)}"
        end

        raw = JSON.parse(response.body)
        artifacts = raw["artifacts"] || []
        raise Error, "No images returned from Stability AI" if artifacts.empty?

        images = artifacts
          .select { |a| a["finishReason"] == "SUCCESS" }
          .map { |a| { data: a["base64"], mime_type: "image/png" } }

        raise Error, "All Stability AI images filtered (content policy or error)" if images.empty?

        { images: images }
      end
    end

    private

    def api_uri(model)
      URI("#{BASE_URL}/#{model}/text-to-image")
    end

    def request_headers
      {
        "Authorization" => "Bearer #{@api_key}",
        "Accept"        => "application/json"
      }
    end
  end
end
