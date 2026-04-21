require "rails_helper"

RSpec.describe "Api::Campaigns", type: :request do
  include_context "api authenticated user"

  let(:api_client) { create(:client, account: account) }

  describe "GET /api/clients/:client_id/campaigns" do
    it "returns campaigns for the client" do
      campaign = create(:campaign, client: api_client)
      get "/api/clients/#{api_client.id}/campaigns"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["name"]).to eq(campaign.name)
    end
  end

  describe "GET /api/clients/:client_id/campaigns/:id" do
    it "returns campaign with full details" do
      campaign = create(:campaign, client: api_client, description: "Test desc", goals: "Test goals")
      get "/api/clients/#{api_client.id}/campaigns/#{campaign.id}"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["description"]).to eq("Test desc")
      expect(response.parsed_body["goals"]).to eq("Test goals")
    end
  end

  describe "POST /api/clients/:client_id/campaigns" do
    it "creates a campaign" do
      post "/api/clients/#{api_client.id}/campaigns",
           params: { campaign: { name: "Q1 Push" } }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["name"]).to eq("Q1 Push")
    end
  end

  describe "PATCH /api/clients/:client_id/campaigns/:id" do
    it "updates the campaign" do
      allow(CampaignSummaryJob).to receive(:perform_later)
      campaign = create(:campaign, client: api_client)
      patch "/api/clients/#{api_client.id}/campaigns/#{campaign.id}",
            params: { campaign: { description: "Updated desc" } }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["description"]).to eq("Updated desc")
    end

    it "triggers summary job when description changes" do
      allow(CampaignSummaryJob).to receive(:perform_later)
      campaign = create(:campaign, client: api_client, description: "old")
      patch "/api/clients/#{api_client.id}/campaigns/#{campaign.id}",
            params: { campaign: { description: "new" } }
      expect(CampaignSummaryJob).to have_received(:perform_later).with(campaign.id)
    end
  end

  describe "DELETE /api/clients/:client_id/campaigns/:id" do
    it "deletes the campaign" do
      campaign = create(:campaign, client: api_client)
      delete "/api/clients/#{api_client.id}/campaigns/#{campaign.id}"
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "POST /api/clients/:client_id/campaigns/:id/summarize" do
    it "triggers summary generation" do
      allow(CampaignSummaryJob).to receive(:perform_later)
      campaign = create(:campaign, client: api_client)
      post "/api/clients/#{api_client.id}/campaigns/#{campaign.id}/summarize"
      expect(response).to have_http_status(:ok)
      expect(CampaignSummaryJob).to have_received(:perform_later).with(campaign.id)
    end
  end
end
