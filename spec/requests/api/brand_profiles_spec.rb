require "rails_helper"

RSpec.describe "Api::BrandProfiles", type: :request do
  include_context "api authenticated user"

  let(:api_client) { create(:client, account: account) }

  describe "GET /api/clients/:client_id/brand_profile" do
    it "returns the brand profile" do
      bp = create(:brand_profile, client: api_client, organization_name: "Acme Inc")
      get "/api/clients/#{api_client.id}/brand_profile"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["organization_name"]).to eq("Acme Inc")
    end

    it "returns 404 when no brand profile exists" do
      get "/api/clients/#{api_client.id}/brand_profile"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/clients/:client_id/brand_profile/upsert" do
    it "creates a brand profile" do
      post "/api/clients/#{api_client.id}/brand_profile/upsert",
           params: { organization_name: "New Corp", primary_domain: "newcorp.com" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["organization_name"]).to eq("New Corp")
    end

    it "updates an existing brand profile" do
      create(:brand_profile, client: api_client, organization_name: "Old Name")
      post "/api/clients/#{api_client.id}/brand_profile/upsert",
           params: { organization_name: "Updated Name" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["organization_name"]).to eq("Updated Name")
    end

    it "syncs lookup associations" do
      geo = create(:geography)
      post "/api/clients/#{api_client.id}/brand_profile/upsert",
           params: { organization_name: "Test", geography_ids: [geo.id] }
      expect(response.parsed_body["geography_ids"]).to include(geo.id)
    end
  end
end
