require "rails_helper"

RSpec.describe EmailJob do
  let(:client) { create(:client) }
  let(:template) { create(:email_template, client: client) }
  let(:email) { create(:email, client: client, email_template: template, state: "pending") }
  let(:audience) { create(:audience, client: client) }

  before do
    allow(ActionCable.server).to receive(:broadcast)
  end

  describe "#perform" do
    it "calls AiMergeService and transitions to merged" do
      merge_service = instance_double(AiMergeService)
      allow(AiMergeService).to receive(:new).and_return(merge_service)
      allow(merge_service).to receive(:call)

      described_class.new.perform(email.id)

      expect(AiMergeService).to have_received(:new).with(email, audience_ids: nil, rejection_context: {})
      expect(merge_service).to have_received(:call)
      expect(email.reload.state).to eq("merged")
    end

    it "passes audience_id when specified" do
      merge_service = instance_double(AiMergeService)
      allow(AiMergeService).to receive(:new).and_return(merge_service)
      allow(merge_service).to receive(:call)

      described_class.new.perform(email.id, audience_id: audience.id.to_s)

      expect(AiMergeService).to have_received(:new).with(
        email,
        audience_ids: [audience.id.to_s],
        rejection_context: {}
      )
    end

    it "passes rejection context when both audience_id and rejection_comment given" do
      merge_service = instance_double(AiMergeService)
      allow(AiMergeService).to receive(:new).and_return(merge_service)
      allow(merge_service).to receive(:call)

      described_class.new.perform(email.id, audience_id: audience.id.to_s, rejection_comment: "Too long")

      expect(AiMergeService).to have_received(:new).with(
        email,
        audience_ids: [audience.id.to_s],
        rejection_context: { audience.id.to_s => "Too long" }
      )
    end

    it "broadcasts merged state via ActionCable" do
      allow(AiMergeService).to receive(:new).and_return(instance_double(AiMergeService, call: nil))

      described_class.new.perform(email.id)

      expect(ActionCable.server).to have_received(:broadcast).with(
        "email:#{email.id}",
        hash_including(state: "merged", email_id: email.id)
      )
    end

    context "when AiMergeService raises an error" do
      it "handles AiMergeService::Error, resets state, and re-raises" do
        allow(AiMergeService).to receive(:new).and_raise(AiMergeService::Error, "API failure")

        expect {
          described_class.new.perform(email.id)
        }.to raise_error(AiMergeService::Error, "API failure")

        expect(email.reload.state).to eq("setup")
      end

      it "broadcasts error via ActionCable" do
        allow(AiMergeService).to receive(:new).and_raise(AiMergeService::Error, "API failure")

        expect {
          described_class.new.perform(email.id)
        }.to raise_error(AiMergeService::Error)

        expect(ActionCable.server).to have_received(:broadcast).with(
          "email:#{email.id}",
          hash_including(error: "API failure")
        )
      end
    end

    context "when unexpected error occurs" do
      it "resets state and re-raises" do
        allow(AiMergeService).to receive(:new).and_raise(RuntimeError, "unexpected")

        expect {
          described_class.new.perform(email.id)
        }.to raise_error(RuntimeError, "unexpected")

        expect(email.reload.state).to eq("setup")
      end
    end
  end
end
