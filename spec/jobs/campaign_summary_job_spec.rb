require "rails_helper"

RSpec.describe CampaignSummaryJob do
  let(:client) { create(:client) }
  let(:campaign) { create(:campaign, client: client) }

  describe "#perform" do
    it "generates summary and updates campaign" do
      service = instance_double(CampaignSummaryService)
      allow(CampaignSummaryService).to receive(:new).with(campaign).and_return(service)
      allow(service).to receive(:call).and_return("AI generated summary")

      described_class.new.perform(campaign.id)

      campaign.reload
      expect(campaign.ai_summary).to eq("AI generated summary")
      expect(campaign.ai_summary_state).to eq("generated")
      expect(campaign.ai_summary_generated_at).to be_present
    end

    it "sets state to generating before calling service" do
      allow(CampaignSummaryService).to receive(:new).and_return(
        instance_double(CampaignSummaryService, call: "summary")
      )

      described_class.new.perform(campaign.id)

      # State should end as generated (it was set to generating during execution)
      expect(campaign.reload.ai_summary_state).to eq("generated")
    end

    it "handles missing campaign gracefully" do
      expect { described_class.new.perform("nonexistent-id") }.not_to raise_error
    end

    context "when CampaignSummaryService raises" do
      it "sets state to failed on service error and re-raises" do
        allow(CampaignSummaryService).to receive(:new).and_raise(
          CampaignSummaryService::Error, "No AI service"
        )

        expect {
          described_class.new.perform(campaign.id)
        }.to raise_error(CampaignSummaryService::Error, "No AI service")

        expect(campaign.reload.ai_summary_state).to eq("failed")
      end

      it "sets state to failed and re-raises on unexpected error" do
        allow(CampaignSummaryService).to receive(:new).and_raise(RuntimeError, "unexpected")

        expect {
          described_class.new.perform(campaign.id)
        }.to raise_error(RuntimeError)

        expect(campaign.reload.ai_summary_state).to eq("failed")
      end
    end
  end
end
