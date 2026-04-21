require 'rails_helper'

RSpec.describe AiProviders::Factory do
  let(:ai_service) { create(:ai_service, slug: "openai") }
  let!(:ai_key) { create(:ai_key, ai_service: ai_service) }

  describe ".for_text" do
    it "returns an OpenAI provider for openai slug" do
      provider = described_class.for_text(ai_service)
      expect(provider).to be_a(AiProviders::Openai)
    end

    it "raises for unsupported slug" do
      ai_service.update!(slug: "unsupported")
      expect { described_class.for_text(ai_service) }.to raise_error(AiProviders::Base::Error, /Unsupported text/)
    end

    it "raises when no API key configured" do
      ai_key.destroy!
      ai_service.reload
      expect { described_class.for_text(ai_service) }.to raise_error(AiProviders::Base::Error, /No API key/)
    end

    it "accepts an AiService id" do
      provider = described_class.for_text(ai_service.id)
      expect(provider).to be_a(AiProviders::Openai)
    end
  end

  describe ".for_image" do
    it "returns an OpenAI provider for openai slug" do
      provider = described_class.for_image(ai_service)
      expect(provider).to be_a(AiProviders::Openai)
    end

    it "raises for unsupported slug" do
      ai_service.update!(slug: "unsupported")
      expect { described_class.for_image(ai_service) }.to raise_error(AiProviders::Base::Error, /Unsupported image/)
    end
  end
end
