require 'rails_helper'

RSpec.describe CampaignSummaryService do
  let(:account) { create(:account) }
  let(:client) { create(:client, account: account) }
  let(:ai_service) { create(:ai_service, slug: "openai") }
  let(:ai_model) { create(:ai_model, ai_service: ai_service, for_text: true) }
  let!(:ai_key) { create(:ai_key, ai_service: ai_service) }
  let(:campaign) { create(:campaign, client: client, name: "Spring Drive", description: "Annual spring campaign", goals: "Raise $50k") }

  # CampaignSummaryService.find_ai_credentials iterates AiKey records and
  # looks for an ai_service with a for_text model. Ensure our fixtures match.
  before do
    ai_key   # force creation so find_ai_credentials can discover it
    ai_model # ensure the for_text model exists on the service
  end

  let(:ai_response) do
    {
      content: "Campaign summary: Spring Drive aims to raise $50k...",
      prompt_tokens: 200, completion_tokens: 100, total_tokens: 300
    }
  end

  let(:provider) { instance_double(AiProviders::Openai, complete: ai_response) }

  before do
    allow(AiProviders::Factory).to receive(:for_text).and_return(provider)
  end

  describe "#call" do
    it "returns a summary string" do
      result = described_class.new(campaign).call
      expect(result).to include("Spring Drive")
    end

    it "calls the AI provider" do
      described_class.new(campaign).call
      expect(provider).to have_received(:complete).once
    end

    it "logs the AI call" do
      expect { described_class.new(campaign).call }.to change(AiLog, :count).by(1)
      expect(AiLog.last.call_type).to eq("campaign_summary")
    end

    it "raises when no AI service configured" do
      ai_key.destroy!
      expect { described_class.new(campaign).call }.to raise_error(CampaignSummaryService::Error, /No text-capable AI/)
    end

    it "raises on empty AI response" do
      allow(provider).to receive(:complete).and_return(content: "", prompt_tokens: 0, completion_tokens: 0, total_tokens: 0)
      expect { described_class.new(campaign).call }.to raise_error(CampaignSummaryService::Error, /Empty response/)
    end

    it "includes description and goals in prompt" do
      described_class.new(campaign).call
      expect(provider).to have_received(:complete) do |args|
        user_content = args[:messages].last[:content]
        expect(user_content).to include("Annual spring campaign")
        expect(user_content).to include("Raise $50k")
      end
    end

    it "includes campaign link summaries" do
      create(:campaign_link, campaign: campaign, url: "https://example.com", title: "Example")
      described_class.new(campaign).call
      expect(provider).to have_received(:complete) do |args|
        user_content = args[:messages].last[:content]
        expect(user_content).to include("https://example.com")
      end
    end

    it "includes campaign dates in prompt" do
      campaign.update!(start_date: Date.new(2026, 3, 1), end_date: Date.new(2026, 3, 31))
      described_class.new(campaign).call
      expect(provider).to have_received(:complete) do |args|
        content = args[:messages].last[:content]
        expect(content).to include("Campaign Dates")
        expect(content).to include("2026-03-01")
      end
    end

    it "includes campaign documents with text" do
      doc = campaign.campaign_documents.build(display_name: "brief.txt", content_text: "Key donor data")
      doc.file.attach(io: StringIO.new("content"), filename: "brief.txt", content_type: "text/plain")
      doc.save!

      described_class.new(campaign).call
      expect(provider).to have_received(:complete) do |args|
        content = args[:messages].last[:content]
        expect(content).to include("Key donor data")
        expect(content).to include("brief.txt")
      end
    end

    it "includes campaign name in prompt" do
      described_class.new(campaign).call
      expect(provider).to have_received(:complete) do |args|
        content = args[:messages].last[:content]
        expect(content).to include("Campaign Name")
        expect(content).to include("Spring Drive")
      end
    end

    it "gracefully handles AiLog save failures" do
      allow(AiLog).to receive(:create!).and_raise(StandardError, "DB error")
      expect { described_class.new(campaign).call }.not_to raise_error
    end

    it "includes document with no extractable text as binary notice" do
      doc = campaign.campaign_documents.build(display_name: "report.docx")
      doc.file.attach(io: StringIO.new("binary"), filename: "report.docx", content_type: "application/octet-stream")
      doc.save!

      described_class.new(campaign).call
      expect(provider).to have_received(:complete) do |args|
        content = args[:messages].last[:content]
        expect(content).to include("Binary file")
      end
    end

    it "includes link descriptions" do
      create(:campaign_link, campaign: campaign, url: "https://site.com",
             title: "Landing Page", link_description: "Main campaign landing page")
      described_class.new(campaign).call
      expect(provider).to have_received(:complete) do |args|
        content = args[:messages].last[:content]
        expect(content).to include("Main campaign landing page")
      end
    end

    it "uses system prompt about campaign strategist" do
      described_class.new(campaign).call
      expect(provider).to have_received(:complete) do |args|
        system = args[:messages].first[:content]
        expect(system).to include("campaign strategist")
      end
    end
  end
end
