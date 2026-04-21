require 'rails_helper'

RSpec.describe AiProviders::Anthropic do
  let(:provider) { described_class.new(api_key: "test-key") }

  let(:success_body) do
    {
      "content" => [{ "text" => '{"headline": "Hello"}' }],
      "usage" => { "input_tokens" => 100, "output_tokens" => 50 }
    }.to_json
  end

  let(:success_response) { instance_double(Net::HTTPResponse, code: "200", body: success_body) }

  before do
    allow(provider).to receive(:http_post).and_return(success_response)
  end

  describe "#complete" do
    it "returns parsed content and token counts" do
      result = provider.complete(model: "claude-3", messages: [
        { role: "system", content: "You are helpful" },
        { role: "user", content: "Hi" }
      ])
      expect(result[:content]).to eq('{"headline": "Hello"}')
      expect(result[:prompt_tokens]).to eq(100)
      expect(result[:completion_tokens]).to eq(50)
      expect(result[:total_tokens]).to eq(150)
    end

    it "appends JSON instruction in json_mode" do
      provider.complete(model: "claude-3", messages: [
        { role: "system", content: "Be helpful" },
        { role: "user", content: "Hi" }
      ], json_mode: true)

      expect(provider).to have_received(:http_post) do |_uri, body, _headers|
        expect(body[:system]).to include("Respond with valid JSON only")
      end
    end

    it "adds system prompt for json_mode without existing system message" do
      provider.complete(model: "claude-3", messages: [
        { role: "user", content: "Hi" }
      ], json_mode: true)

      expect(provider).to have_received(:http_post) do |_uri, body, _headers|
        expect(body[:system]).to eq("Respond with valid JSON only.")
      end
    end

    it "raises on rate limit" do
      rate_response = instance_double(Net::HTTPResponse, code: "429", :[] => "30")
      allow(provider).to receive(:http_post).and_return(rate_response)
      allow(provider).to receive(:sleep) # prevent actual sleep

      expect { provider.complete(model: "m", messages: [{ role: "user", content: "hi" }]) }
        .to raise_error(AiProviders::Base::Error, /rate limit/)
    end

    it "raises on API error" do
      error_response = instance_double(Net::HTTPResponse, code: "500", body: "Internal Server Error")
      allow(provider).to receive(:http_post).and_return(error_response)

      expect { provider.complete(model: "m", messages: [{ role: "user", content: "hi" }]) }
        .to raise_error(AiProviders::Base::Error, /Anthropic API error 500/)
    end

    it "raises on empty response" do
      empty_body = { "content" => [{ "text" => "" }], "usage" => {} }.to_json
      empty_response = instance_double(Net::HTTPResponse, code: "200", body: empty_body)
      allow(provider).to receive(:http_post).and_return(empty_response)

      expect { provider.complete(model: "m", messages: [{ role: "user", content: "hi" }]) }
        .to raise_error(AiProviders::Base::Error, /Empty response/)
    end
  end
end
