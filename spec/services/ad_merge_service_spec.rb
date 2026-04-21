require 'rails_helper'

RSpec.describe AdMergeService do
  let(:account) { create(:account) }
  let(:client) { create(:client, account: account) }
  let(:ai_service) { create(:ai_service, slug: "openai") }
  let(:ai_model) { create(:ai_model, ai_service: ai_service, for_text: true) }
  let!(:ai_key) { create(:ai_key, ai_service: ai_service) }
  let(:audience) { create(:audience, client: client, name: "Millennials") }
  let(:ad) do
    create(:ad, client: client, ai_service: ai_service, ai_model: ai_model,
           width: 300, height: 250,
           parsed_layers: [
             { "id" => "layer1", "type" => "text", "content" => "Big Sale", "font_size" => 24, "x" => 10, "y" => 30 },
             { "id" => "layer2", "type" => "text", "content" => "Shop Now", "font_size" => 14, "x" => 10, "y" => 200 }
           ])
  end

  before do
    create(:ad_audience, ad: ad, audience: audience)
  end

  let(:ai_response) do
    {
      content: { "layer1" => "Mega Savings", "layer2" => "Buy Today" }.to_json,
      prompt_tokens: 80, completion_tokens: 40, total_tokens: 120
    }
  end

  let(:provider) { instance_double(AiProviders::Openai, complete: ai_response) }

  before do
    allow(AiProviders::Factory).to receive(:for_text).and_return(provider)
  end

  describe "#call" do
    it "creates an ad version with generated layers" do
      described_class.new(ad).call

      version = ad.ad_versions.find_by(audience: audience)
      expect(version).to be_present
      expect(version.state).to eq("active")
      expect(version.generated_layers.size).to eq(2)
      expect(version.generated_layers.first["content"]).to eq("Mega Savings")
    end

    it "logs the AI call" do
      expect { described_class.new(ad).call }.to change(AiLog, :count).by(1)
      expect(AiLog.last.call_type).to eq("ad")
    end

    it "raises when no text layers exist" do
      ad.update!(parsed_layers: [{ "id" => "bg", "type" => "image" }])
      expect { described_class.new(ad).call }.to raise_error(AdMergeService::Error, /No text layers/)
    end

    it "raises when no audiences assigned" do
      ad.ad_audiences.destroy_all
      expect { described_class.new(ad).call }.to raise_error(AdMergeService::Error, /No audiences/)
    end

    it "raises on empty AI response" do
      allow(provider).to receive(:complete).and_return(content: "", prompt_tokens: 0, completion_tokens: 0, total_tokens: 0)
      expect { described_class.new(ad).call }.to raise_error(AdMergeService::Error, /Empty response/)
    end

    it "skips audiences with existing active versions" do
      create(:ad_version, ad: ad, audience: audience,
             ai_service: ai_service, ai_model: ai_model, state: "active")
      described_class.new(ad).call
      expect(provider).not_to have_received(:complete)
    end

    it "attaches to pre-existing generating version" do
      pre_version = create(:ad_version, ad: ad, audience: audience,
                           ai_service: ai_service, ai_model: ai_model, state: "generating")
      described_class.new(ad).call

      pre_version.reload
      expect(pre_version.state).to eq("active")
      expect(pre_version.generated_layers).to be_present
    end

    it "includes rejection context in the prompt" do
      rejection = { audience.id.to_s => "Too generic" }
      described_class.new(ad, rejection_context: rejection).call

      expect(provider).to have_received(:complete) do |args|
        user_content = args[:messages].last[:content]
        expect(user_content).to include("Too generic")
      end
    end

    it "uses layer_overrides for enriched text" do
      ad.update!(layer_overrides: { "layer1" => { "content" => "Override Text" } })
      described_class.new(ad).call

      expect(provider).to have_received(:complete) do |args|
        user_content = args[:messages].last[:content]
        expect(user_content).to include("Override Text")
      end
    end
  end
end
