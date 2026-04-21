require 'rails_helper'

RSpec.describe AiProviders::StabilityAi do
  let(:provider) { described_class.new(api_key: "test-key") }

  let(:success_body) do
    {
      "artifacts" => [
        { "base64" => "iVBORw0KGgo=", "finishReason" => "SUCCESS" }
      ]
    }.to_json
  end

  let(:success_response) { instance_double(Net::HTTPResponse, code: "200", body: success_body) }

  before do
    allow(provider).to receive(:http_post).and_return(success_response)
  end

  describe "#generate_image" do
    it "returns image data" do
      result = provider.generate_image(model: "stable-diffusion-xl", prompt: "A cat")
      expect(result[:images].size).to eq(1)
      expect(result[:images].first[:data]).to eq("iVBORw0KGgo=")
      expect(result[:images].first[:mime_type]).to eq("image/png")
    end

    it "sends correct body parameters" do
      provider.generate_image(model: "sd-model", prompt: "A dog", width: 512, height: 512, steps: 20)
      expect(provider).to have_received(:http_post) do |uri, body, _headers|
        expect(body[:text_prompts].first[:text]).to eq("A dog")
        expect(body[:width]).to eq(512)
        expect(body[:steps]).to eq(20)
      end
    end

    it "uses Bearer auth" do
      provider.generate_image(model: "m", prompt: "p")
      expect(provider).to have_received(:http_post) do |_uri, _body, headers|
        expect(headers["Authorization"]).to eq("Bearer test-key")
        expect(headers["Accept"]).to eq("application/json")
      end
    end

    it "raises on rate limit" do
      rate_response = instance_double(Net::HTTPResponse, code: "429", :[] => nil)
      allow(provider).to receive(:http_post).and_return(rate_response)
      allow(provider).to receive(:sleep)

      expect { provider.generate_image(model: "m", prompt: "p") }
        .to raise_error(AiProviders::Base::Error, /rate limit/)
    end

    it "raises on API error" do
      error_response = instance_double(Net::HTTPResponse, code: "500", body: "Server Error")
      allow(provider).to receive(:http_post).and_return(error_response)

      expect { provider.generate_image(model: "m", prompt: "p") }
        .to raise_error(AiProviders::Base::Error, /Stability AI API error/)
    end

    it "raises when no images returned" do
      empty_body = { "artifacts" => [] }.to_json
      empty_response = instance_double(Net::HTTPResponse, code: "200", body: empty_body)
      allow(provider).to receive(:http_post).and_return(empty_response)

      expect { provider.generate_image(model: "m", prompt: "p") }
        .to raise_error(AiProviders::Base::Error, /No images/)
    end

    it "raises when all images filtered" do
      filtered_body = { "artifacts" => [{ "base64" => "x", "finishReason" => "CONTENT_FILTERED" }] }.to_json
      filtered_response = instance_double(Net::HTTPResponse, code: "200", body: filtered_body)
      allow(provider).to receive(:http_post).and_return(filtered_response)

      expect { provider.generate_image(model: "m", prompt: "p") }
        .to raise_error(AiProviders::Base::Error, /filtered/)
    end
  end
end
