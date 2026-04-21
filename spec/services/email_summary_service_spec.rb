require 'rails_helper'

RSpec.describe EmailSummaryService do
  let(:account) { create(:account) }
  let(:client) { create(:client, account: account) }
  let(:ai_service) { create(:ai_service, slug: "openai") }
  let(:ai_model) { create(:ai_model, ai_service: ai_service, for_text: true) }
  let!(:ai_key) { create(:ai_key, ai_service: ai_service) }
  let(:template) { create(:email_template, client: client, name: "Newsletter") }
  let(:email) { create(:email, client: client, email_template: template) }

  before do
    ai_key
    ai_model
  end

  let(:ai_response) do
    {
      content: "Summary of documents for Newsletter template...",
      prompt_tokens: 150, completion_tokens: 80, total_tokens: 230
    }
  end

  let(:provider) { instance_double(AiProviders::Openai, complete: ai_response) }

  before do
    allow(AiProviders::Factory).to receive(:for_text).and_return(provider)
  end

  describe "#call" do
    let!(:doc) do
      doc = email.email_documents.build(display_name: "brief.txt", content_text: "Key facts about our donors")
      doc.file.attach(io: StringIO.new("content"), filename: "brief.txt", content_type: "text/plain")
      doc.save!
      doc
    end

    it "returns a summary string" do
      result = described_class.new(email).call
      expect(result).to include("Summary")
    end

    it "calls the AI provider" do
      described_class.new(email).call
      expect(provider).to have_received(:complete).once
    end

    it "logs the AI call" do
      expect { described_class.new(email).call }.to change(AiLog, :count).by(1)
      expect(AiLog.last.call_type).to eq("email_summary")
    end

    it "raises when no AI service configured" do
      ai_key.destroy!
      expect { described_class.new(email).call }.to raise_error(EmailSummaryService::Error, /No text-capable AI/)
    end

    it "raises when no documents with text" do
      email.email_documents.destroy_all
      expect { described_class.new(email).call }.to raise_error(EmailSummaryService::Error, /No documents/)
    end

    it "raises on empty AI response" do
      allow(provider).to receive(:complete).and_return(content: "", prompt_tokens: 0, completion_tokens: 0, total_tokens: 0)
      expect { described_class.new(email).call }.to raise_error(EmailSummaryService::Error, /Empty response/)
    end

    it "includes document text in prompt" do
      described_class.new(email).call
      expect(provider).to have_received(:complete) do |args|
        user_content = args[:messages].last[:content]
        expect(user_content).to include("Key facts about our donors")
      end
    end

    it "includes template name in prompt" do
      described_class.new(email).call
      expect(provider).to have_received(:complete) do |args|
        content = args[:messages].last[:content]
        expect(content).to include("Newsletter")
      end
    end

    it "includes system prompt" do
      described_class.new(email).call
      expect(provider).to have_received(:complete) do |args|
        system_content = args[:messages].first[:content]
        expect(system_content).to include("expert email copywriter")
      end
    end

    it "gracefully handles AiLog save failures" do
      allow(AiLog).to receive(:create!).and_raise(StandardError, "DB error")
      expect { described_class.new(email).call }.not_to raise_error
    end

    it "uses low temperature for factual summary" do
      described_class.new(email).call
      expect(provider).to have_received(:complete) do |args|
        expect(args[:temperature]).to eq(0.3)
      end
    end

    it "includes document name in prompt" do
      described_class.new(email).call
      expect(provider).to have_received(:complete) do |args|
        content = args[:messages].last[:content]
        expect(content).to include("brief.txt")
      end
    end

    it "filters out documents with no extractable text" do
      empty_doc = email.email_documents.build(display_name: "empty.bin")
      empty_doc.file.attach(io: StringIO.new("binary"), filename: "empty.bin", content_type: "application/octet-stream")
      empty_doc.save!

      described_class.new(email).call
      expect(provider).to have_received(:complete) do |args|
        content = args[:messages].last[:content]
        expect(content).not_to include("empty.bin")
      end
    end
  end
end
