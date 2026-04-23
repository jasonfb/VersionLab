require "rails_helper"

RSpec.describe "Api::CampaignLinks", type: :request do
  include_context "api authenticated user"

  let(:api_client) { create(:client, account: account) }
  let(:campaign) { create(:campaign, client: api_client) }

  before do
    allow(FetchLinkPreviewJob).to receive(:perform_later)
    allow(CampaignSummaryJob).to receive(:perform_later)
  end

  describe "GET /api/clients/:client_id/campaigns/:campaign_id/campaign_links" do
    it "returns links for the campaign" do
      link = create(:campaign_link, campaign: campaign)
      get "/api/clients/#{api_client.id}/campaigns/#{campaign.id}/campaign_links"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["url"]).to eq(link.url)
    end
  end

  describe "POST /api/clients/:client_id/campaigns/:campaign_id/campaign_links" do
    it "creates a link" do
      post "/api/clients/#{api_client.id}/campaigns/#{campaign.id}/campaign_links",
           params: { url: "https://example.com" }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["url"]).to eq("https://example.com")
    end

    it "rejects blank url" do
      post "/api/clients/#{api_client.id}/campaigns/#{campaign.id}/campaign_links",
           params: { url: "" }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /api/clients/:client_id/campaigns/:campaign_id/campaign_links/:id" do
    it "deletes the link" do
      link = create(:campaign_link, campaign: campaign)
      delete "/api/clients/#{api_client.id}/campaigns/#{campaign.id}/campaign_links/#{link.id}"
      expect(response).to have_http_status(:no_content)
    end
  end
end
