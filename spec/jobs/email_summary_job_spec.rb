require "rails_helper"

RSpec.describe EmailSummaryJob do
  let(:client) { create(:client) }
  let(:template) { create(:email_template, client: client) }
  let(:email) { create(:email, client: client, email_template: template) }

  describe "#perform" do
    it "generates summary and updates email" do
      service = instance_double(EmailSummaryService)
      allow(EmailSummaryService).to receive(:new).with(email).and_return(service)
      allow(service).to receive(:call).and_return("Email context summary")

      described_class.new.perform(email.id)

      email.reload
      expect(email.ai_summary).to eq("Email context summary")
      expect(email.ai_summary_state).to eq("generated")
      expect(email.ai_summary_generated_at).to be_present
    end

    it "handles missing email gracefully" do
      expect { described_class.new.perform("nonexistent-id") }.not_to raise_error
    end

    context "when EmailSummaryService raises" do
      it "sets state to failed on service error" do
        allow(EmailSummaryService).to receive(:new).and_raise(
          EmailSummaryService::Error, "No AI"
        )

        described_class.new.perform(email.id)

        expect(email.reload.ai_summary_state).to eq("failed")
      end

      it "sets state to failed and re-raises on unexpected error" do
        allow(EmailSummaryService).to receive(:new).and_raise(RuntimeError, "boom")

        expect {
          described_class.new.perform(email.id)
        }.to raise_error(RuntimeError)

        expect(email.reload.ai_summary_state).to eq("failed")
      end
    end
  end
end
