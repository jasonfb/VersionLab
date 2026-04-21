require 'rails_helper'

RSpec.describe AiProviders::Openai do
  let(:provider) { described_class.new(api_key: "test-key") }

  describe "#complete" do
    let(:client_double) { instance_double(OpenAI::Client) }

    before do
      allow(OpenAI::Client).to receive(:new).and_return(client_double)
    end

    it "returns content and token counts" do
      allow(client_double).to receive(:chat).and_return({
        "choices" => [{ "message" => { "content" => '{"result": "ok"}' } }],
        "usage" => { "prompt_tokens" => 50, "completion_tokens" => 25, "total_tokens" => 75 }
      })

      result = provider.complete(model: "gpt-4", messages: [{ role: "user", content: "hi" }])
      expect(result[:content]).to eq('{"result": "ok"}')
      expect(result[:total_tokens]).to eq(75)
    end

    it "passes json_mode response_format" do
      allow(client_double).to receive(:chat).and_return({
        "choices" => [{ "message" => { "content" => "{}" } }],
        "usage" => {}
      })

      provider.complete(model: "gpt-4", messages: [{ role: "user", content: "hi" }], json_mode: true)
      expect(client_double).to have_received(:chat) do |args|
        expect(args[:parameters][:response_format]).to eq({ type: "json_object" })
      end
    end

    it "raises on empty response" do
      allow(client_double).to receive(:chat).and_return({
        "choices" => [{ "message" => { "content" => "" } }],
        "usage" => {}
      })

      expect { provider.complete(model: "m", messages: [{ role: "user", content: "hi" }]) }
        .to raise_error(AiProviders::Base::Error, /Empty response/)
    end

    it "handles rate limit errors" do
      allow(client_double).to receive(:chat).and_raise(
        Faraday::TooManyRequestsError.new(
          nil,
          { status: 429, headers: { "retry-after" => "5" }, body: "" }
        )
      )
      allow(provider).to receive(:sleep)

      expect { provider.complete(model: "m", messages: [{ role: "user", content: "hi" }]) }
        .to raise_error(AiProviders::Base::Error, /rate limit/)
    end
  end

  describe "#generate_image" do
    let(:client_double) { instance_double(OpenAI::Client) }
    let(:images_double) { double("images") }

    before do
      allow(OpenAI::Client).to receive(:new).and_return(client_double)
      allow(client_double).to receive(:images).and_return(images_double)
    end

    it "returns base64 image data" do
      allow(images_double).to receive(:generate).and_return({
        "data" => [{ "b64_json" => "base64data" }]
      })

      result = provider.generate_image(model: "dall-e-3", prompt: "A cat")
      expect(result[:images].first[:data]).to eq("base64data")
    end

    it "raises on empty image response" do
      allow(images_double).to receive(:generate).and_return({
        "data" => [{ "b64_json" => "" }]
      })

      expect { provider.generate_image(model: "m", prompt: "p") }
        .to raise_error(AiProviders::Base::Error, /Empty image/)
    end
  end
end
