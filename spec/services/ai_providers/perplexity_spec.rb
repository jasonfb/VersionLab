require 'rails_helper'

RSpec.describe AiProviders::Perplexity do
  let(:provider) { described_class.new(api_key: "test-key") }

  let(:success_body) do
    {
      "choices" => [{ "message" => { "content" => '{"answer": "yes"}' } }],
      "usage" => { "prompt_tokens" => 60, "completion_tokens" => 30, "total_tokens" => 90 }
    }.to_json
  end

  let(:success_response) { instance_double(Net::HTTPResponse, code: "200", body: success_body) }

  before do
    allow(provider).to receive(:http_post).and_return(success_response)
  end

  describe "#complete" do
    it "returns parsed content and token counts" do
      result = provider.complete(model: "pplx-7b", messages: [
        { role: "user", content: "Hi" }
      ])
      expect(result[:content]).to eq('{"answer": "yes"}')
      expect(result[:prompt_tokens]).to eq(60)
      expect(result[:total_tokens]).to eq(90)
    end

    it "appends JSON instruction to system message in json_mode" do
      provider.complete(model: "pplx-7b", messages: [
        { role: "system", content: "Be helpful" },
        { role: "user", content: "Hi" }
      ], json_mode: true)

      expect(provider).to have_received(:http_post) do |_uri, body, _headers|
        system_msg = body[:messages].find { |m| m[:role] == "system" }
        expect(system_msg[:content]).to include("Respond with valid JSON only")
      end
    end

    it "creates system message for json_mode when none exists" do
      provider.complete(model: "pplx-7b", messages: [
        { role: "user", content: "Hi" }
      ], json_mode: true)

      expect(provider).to have_received(:http_post) do |_uri, body, _headers|
        system_msg = body[:messages].find { |m| m[:role] == "system" }
        expect(system_msg).to be_present
      end
    end

    it "uses Bearer auth header" do
      provider.complete(model: "pplx-7b", messages: [{ role: "user", content: "Hi" }])

      expect(provider).to have_received(:http_post) do |_uri, _body, headers|
        expect(headers["Authorization"]).to eq("Bearer test-key")
      end
    end

    it "raises on rate limit" do
      rate_response = instance_double(Net::HTTPResponse, code: "429", :[] => nil)
      allow(provider).to receive(:http_post).and_return(rate_response)
      allow(provider).to receive(:sleep)

      expect { provider.complete(model: "m", messages: [{ role: "user", content: "hi" }]) }
        .to raise_error(AiProviders::Base::Error, /rate limit/)
    end

    it "raises on empty response" do
      empty_body = { "choices" => [{ "message" => { "content" => "" } }], "usage" => {} }.to_json
      empty_response = instance_double(Net::HTTPResponse, code: "200", body: empty_body)
      allow(provider).to receive(:http_post).and_return(empty_response)

      expect { provider.complete(model: "m", messages: [{ role: "user", content: "hi" }]) }
        .to raise_error(AiProviders::Base::Error, /Empty response/)
    end
  end
end
