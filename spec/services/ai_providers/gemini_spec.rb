require 'rails_helper'

RSpec.describe AiProviders::Gemini do
  let(:provider) { described_class.new(api_key: "test-key") }

  let(:success_body) do
    {
      "candidates" => [{ "content" => { "parts" => [{ "text" => '{"result": "ok"}' }] } }],
      "usageMetadata" => { "promptTokenCount" => 80, "candidatesTokenCount" => 40, "totalTokenCount" => 120 }
    }.to_json
  end

  let(:success_response) { instance_double(Net::HTTPResponse, code: "200", body: success_body) }

  before do
    allow(provider).to receive(:http_post).and_return(success_response)
  end

  describe "#complete" do
    it "returns parsed content and token counts" do
      result = provider.complete(model: "gemini-pro", messages: [
        { role: "system", content: "Be helpful" },
        { role: "user", content: "Hi" }
      ])
      expect(result[:content]).to eq('{"result": "ok"}')
      expect(result[:prompt_tokens]).to eq(80)
      expect(result[:total_tokens]).to eq(120)
    end

    it "maps assistant role to model" do
      provider.complete(model: "gemini-pro", messages: [
        { role: "user", content: "Hi" },
        { role: "assistant", content: "Hello" },
        { role: "user", content: "Bye" }
      ])

      expect(provider).to have_received(:http_post) do |_uri, body, _headers|
        roles = body[:contents].map { |c| c[:role] }
        expect(roles).to eq(%w[user model user])
      end
    end

    it "sets responseMimeType in json_mode" do
      provider.complete(model: "gemini-pro", messages: [
        { role: "user", content: "Hi" }
      ], json_mode: true)

      expect(provider).to have_received(:http_post) do |_uri, body, _headers|
        expect(body[:generationConfig][:responseMimeType]).to eq("application/json")
      end
    end

    it "raises on rate limit" do
      rate_response = instance_double(Net::HTTPResponse, code: "429", :[] => nil)
      allow(provider).to receive(:http_post).and_return(rate_response)
      allow(provider).to receive(:sleep)

      expect { provider.complete(model: "m", messages: [{ role: "user", content: "hi" }]) }
        .to raise_error(AiProviders::Base::Error, /rate limit/)
    end

    it "raises on API error" do
      error_response = instance_double(Net::HTTPResponse, code: "400", body: "Bad Request")
      allow(provider).to receive(:http_post).and_return(error_response)

      expect { provider.complete(model: "m", messages: [{ role: "user", content: "hi" }]) }
        .to raise_error(AiProviders::Base::Error, /Gemini API error/)
    end
  end
end
