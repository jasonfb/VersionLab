require "rails_helper"

RSpec.describe "Api::CampaignDocuments", type: :request do
  include_context "api authenticated user"

  let(:api_client) { create(:client, account: account) }
  let(:campaign) { create(:campaign, client: api_client) }

  before { allow(CampaignSummaryJob).to receive(:perform_later) }

  describe "GET /api/clients/:client_id/campaigns/:campaign_id/campaign_documents" do
    it "returns documents for the campaign" do
      doc = create(:campaign_document, campaign: campaign)
      get "/api/clients/#{api_client.id}/campaigns/#{campaign.id}/campaign_documents"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["display_name"]).to eq(doc.display_name)
    end
  end

  describe "POST /api/clients/:client_id/campaigns/:campaign_id/campaign_documents" do
    it "uploads a document" do
      file = fixture_file_upload("spec/fixtures/test.txt", "text/plain")
      post "/api/clients/#{api_client.id}/campaigns/#{campaign.id}/campaign_documents",
           params: { file: file }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["display_name"]).to eq("test.txt")
    end

    it "rejects missing file" do
      post "/api/clients/#{api_client.id}/campaigns/#{campaign.id}/campaign_documents"
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /api/clients/:client_id/campaigns/:campaign_id/campaign_documents/:id" do
    it "deletes the document" do
      doc = create(:campaign_document, campaign: campaign)
      delete "/api/clients/#{api_client.id}/campaigns/#{campaign.id}/campaign_documents/#{doc.id}"
      expect(response).to have_http_status(:no_content)
    end
  end
end
