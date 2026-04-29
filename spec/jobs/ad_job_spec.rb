require "rails_helper"

RSpec.describe AdJob do
  let(:client) { create(:client) }
  let(:ad) { create(:ad, client: client, state: "pending") }
  let(:audience) { create(:audience, client: client) }

  before do
    allow(ActionCable.server).to receive(:broadcast)
  end

  describe "#perform" do
    it "calls AdMergeService and transitions to merged (no resizes)" do
      merge_service = instance_double(AdMergeService)
      allow(AdMergeService).to receive(:new).and_return(merge_service)
      allow(merge_service).to receive(:call)

      described_class.new.perform(ad.id)

      expect(AdMergeService).to have_received(:new).with(
        ad, audience_ids: nil, rejection_context: {}, ad_resize_id: nil
      )
      expect(ad.reload.state).to eq("merged")
    end

    it "iterates resized ad_resizes when present" do
      resize = create(:ad_resize, ad: ad, state: "resized", width: 300, height: 250)
      merge_service = instance_double(AdMergeService)
      allow(AdMergeService).to receive(:new).and_return(merge_service)
      allow(merge_service).to receive(:call)

      described_class.new.perform(ad.id)

      expect(AdMergeService).to have_received(:new).with(
        ad, audience_ids: nil, rejection_context: {}, ad_resize_id: resize.id
      )
    end

    it "uses specific ad_resize_id when provided" do
      resize = create(:ad_resize, ad: ad, state: "resized", width: 300, height: 250)
      merge_service = instance_double(AdMergeService)
      allow(AdMergeService).to receive(:new).and_return(merge_service)
      allow(merge_service).to receive(:call)

      described_class.new.perform(ad.id, ad_resize_id: resize.id)

      expect(AdMergeService).to have_received(:new).with(
        ad, audience_ids: nil, rejection_context: {}, ad_resize_id: resize.id
      ).once
    end

    it "passes audience_id and rejection_comment" do
      merge_service = instance_double(AdMergeService)
      allow(AdMergeService).to receive(:new).and_return(merge_service)
      allow(merge_service).to receive(:call)

      described_class.new.perform(ad.id, audience_id: audience.id.to_s, rejection_comment: "Wrong tone")

      expect(AdMergeService).to have_received(:new).with(
        ad,
        audience_ids: [audience.id.to_s],
        rejection_context: { audience.id.to_s => "Wrong tone" },
        ad_resize_id: nil
      )
    end

    it "broadcasts merged state" do
      allow(AdMergeService).to receive(:new).and_return(instance_double(AdMergeService, call: nil))

      described_class.new.perform(ad.id)

      expect(ActionCable.server).to have_received(:broadcast).with(
        "ad:#{ad.id}",
        hash_including(state: "merged")
      )
    end

    context "when AdMergeService raises" do
      it "handles AdMergeService::Error, resets state, and re-raises" do
        allow(AdMergeService).to receive(:new).and_raise(AdMergeService::Error, "AI error")

        expect {
          described_class.new.perform(ad.id)
        }.to raise_error(AdMergeService::Error, "AI error")

        expect(ad.reload.state).to eq("setup")
      end
    end

    context "when unexpected error occurs" do
      it "resets state and re-raises" do
        allow(AdMergeService).to receive(:new).and_raise(RuntimeError, "boom")

        expect {
          described_class.new.perform(ad.id)
        }.to raise_error(RuntimeError, "boom")

        expect(ad.reload.state).to eq("setup")
      end
    end
  end
end
