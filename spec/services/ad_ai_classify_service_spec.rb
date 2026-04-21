require 'rails_helper'

RSpec.describe AdAiClassifyService do
  let(:account) { create(:account) }
  let(:client) { create(:client, account: account) }
  let(:ai_service) { create(:ai_service, slug: "openai") }
  let(:ai_model) { create(:ai_model, ai_service: ai_service, for_text: true) }
  let!(:ai_key) { create(:ai_key, ai_service: ai_service) }
  let(:ad) do
    create(:ad, client: client, ai_service: ai_service, ai_model: ai_model,
           parsed_layers: [
             { "id" => "l1", "type" => "text", "content" => "Big Headline", "font_size" => 36, "x" => 10, "y" => 20 },
             { "id" => "l2", "type" => "text", "content" => "Shop Now", "font_size" => 14, "x" => 10, "y" => 200 }
           ])
  end

  let(:ai_classification) do
    {
      "layers" => [
        { "id" => "l1", "role" => "headline", "continuation_of" => nil },
        { "id" => "l2", "role" => "cta", "continuation_of" => nil }
      ]
    }
  end

  let(:ai_response) do
    {
      content: ai_classification.to_json,
      prompt_tokens: 100, completion_tokens: 50, total_tokens: 150
    }
  end

  let(:provider) { instance_double(AiProviders::Openai, complete: ai_response) }

  before do
    allow(AiProviders::Factory).to receive(:for_text).and_return(provider)
  end

  describe "#call" do
    it "updates classified_layers on the ad" do
      result = described_class.new(ad).call
      ad.reload
      expect(ad.classified_layers).to be_present

      headline = ad.classified_layers.find { |l| l["id"] == "l1" }
      expect(headline["role"]).to eq("headline")
    end

    it "assigns roles from AI response" do
      result = described_class.new(ad).call
      cta = result.find { |l| l["id"] == "l2" }
      expect(cta["role"]).to eq("cta")
    end

    it "logs the AI call" do
      expect { described_class.new(ad).call }.to change(AiLog, :count).by(1)
    end

    it "raises when ad has no text layers" do
      ad.update!(parsed_layers: [{ "id" => "bg", "type" => "image" }],
                 classified_layers: [{ "id" => "bg", "type" => "image" }])
      expect { described_class.new(ad).call }.to raise_error(AdAiClassifyService::Error, /no text layers/)
    end

    it "raises when ad has no text layers" do
      ad.update!(parsed_layers: [{ "id" => "bg", "type" => "image" }])
      expect { described_class.new(ad).call }.to raise_error(AdAiClassifyService::Error, /no text layers/)
    end

    it "raises when no AI model available" do
      ai_key.destroy!
      ad.update!(ai_model: nil, ai_service: nil)
      expect { described_class.new(ad).call }.to raise_error(AdAiClassifyService::Error, /No AI service/)
    end

    it "handles continuation_of links" do
      ai_classification_with_cont = {
        "layers" => [
          { "id" => "l1", "role" => "body", "continuation_of" => nil },
          { "id" => "l2", "role" => "body", "continuation_of" => "l1" }
        ]
      }
      allow(provider).to receive(:complete).and_return(
        content: ai_classification_with_cont.to_json,
        prompt_tokens: 100, completion_tokens: 50, total_tokens: 150
      )
      described_class.new(ad).call

      ad.reload
      layer2 = ad.classified_layers.find { |l| l["id"] == "l2" }
      expect(layer2["continuation_of"]).to eq("l1")
    end

    it "rejects self-referencing continuation" do
      ai_classification["layers"][0]["continuation_of"] = "l1"
      described_class.new(ad).call

      ad.reload
      layer1 = ad.classified_layers.find { |l| l["id"] == "l1" }
      expect(layer1).not_to have_key("continuation_of")
    end

    it "sets confidence on classified layers" do
      described_class.new(ad).call
      ad.reload
      ad.classified_layers.select { |l| l["type"] == "text" }.each do |layer|
        expect(layer["confidence"]).to eq(0.95)
      end
    end

    it "wraps provider errors" do
      allow(provider).to receive(:complete).and_raise(AiProviders::Base::Error, "Timeout")
      expect { described_class.new(ad).call }.to raise_error(AdAiClassifyService::Error, "Timeout")
    end
  end
end
