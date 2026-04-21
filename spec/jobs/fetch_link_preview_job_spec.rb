require "rails_helper"

RSpec.describe FetchLinkPreviewJob do
  let(:client) { create(:client) }
  let(:campaign) { create(:campaign, client: client) }

  before do
    allow(FetchLinkPreviewJob).to receive(:perform_later).and_call_original
    allow(CampaignSummaryJob).to receive(:perform_later)
  end

  describe "#perform" do
    let(:link) { create(:campaign_link, campaign: campaign, url: "https://example.com") }

    let(:html) do
      <<~HTML
        <html>
        <head>
          <title>Example Page</title>
          <meta property="og:title" content="OG Title" />
          <meta property="og:description" content="OG Description" />
          <meta property="og:image" content="https://example.com/image.jpg" />
        </head>
        <body></body>
        </html>
      HTML
    end

    it "fetches and parses OG metadata" do
      allow(URI).to receive(:open).and_return(StringIO.new(html))

      described_class.new.perform(link.id)

      link.reload
      expect(link.title).to eq("OG Title")
      expect(link.link_description).to eq("OG Description")
      expect(link.image_url).to eq("https://example.com/image.jpg")
      expect(link.fetched_at).to be_present
    end

    it "falls back to <title> tag when no OG title" do
      html_no_og = '<html><head><title>Fallback Title</title></head><body></body></html>'
      allow(URI).to receive(:open).and_return(StringIO.new(html_no_og))

      described_class.new.perform(link.id)

      expect(link.reload.title).to eq("Fallback Title")
    end

    it "truncates long titles and descriptions" do
      long_title = "A" * 300
      long_desc = "B" * 600
      html_long = <<~HTML
        <html><head>
        <meta property="og:title" content="#{long_title}" />
        <meta property="og:description" content="#{long_desc}" />
        </head></html>
      HTML
      allow(URI).to receive(:open).and_return(StringIO.new(html_long))

      described_class.new.perform(link.id)

      link.reload
      expect(link.title.length).to be <= 255
      expect(link.link_description.length).to be <= 500
    end

    it "triggers CampaignSummaryJob after success" do
      allow(URI).to receive(:open).and_return(StringIO.new(html))

      described_class.new.perform(link.id)

      expect(CampaignSummaryJob).to have_received(:perform_later).with(campaign.id)
    end

    it "handles fetch errors gracefully" do
      allow(URI).to receive(:open).and_raise(OpenURI::HTTPError.new("404", StringIO.new))

      described_class.new.perform(link.id)

      expect(link.reload.fetched_at).to be_present
    end

    it "triggers CampaignSummaryJob even on failure" do
      allow(URI).to receive(:open).and_raise(Timeout::Error)

      described_class.new.perform(link.id)

      expect(CampaignSummaryJob).to have_received(:perform_later).with(campaign.id)
    end

    it "handles missing link gracefully" do
      expect { described_class.new.perform("nonexistent-id") }.not_to raise_error
    end
  end
end
