require "rails_helper"

RSpec.describe "Api::Audiences", type: :request do
  include_context "api authenticated user"

  let(:api_client) { create(:client, account: account) }

  describe "GET /api/clients/:client_id/audiences" do
    it "returns audiences for the client" do
      audience = create(:audience, client: api_client)
      get "/api/clients/#{api_client.id}/audiences"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.length).to eq(1)
      expect(response.parsed_body.first["name"]).to eq(audience.name)
    end
  end

  describe "GET /api/clients/:client_id/audiences/:id" do
    it "returns a single audience" do
      audience = create(:audience, client: api_client)
      get "/api/clients/#{api_client.id}/audiences/#{audience.id}"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(audience.id)
    end
  end

  describe "POST /api/clients/:client_id/audiences" do
    it "creates an audience" do
      post "/api/clients/#{api_client.id}/audiences",
           params: { audience: { name: "Young Professionals", details: "Ages 25-35" } }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["name"]).to eq("Young Professionals")
    end

    it "rejects blank name" do
      post "/api/clients/#{api_client.id}/audiences",
           params: { audience: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /api/clients/:client_id/audiences/:id" do
    it "updates an audience" do
      audience = create(:audience, client: api_client)
      patch "/api/clients/#{api_client.id}/audiences/#{audience.id}",
            params: { audience: { name: "Updated Name" } }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["name"]).to eq("Updated Name")
    end
  end

  describe "DELETE /api/clients/:client_id/audiences/:id" do
    it "deletes an audience" do
      audience = create(:audience, client: api_client)
      delete "/api/clients/#{api_client.id}/audiences/#{audience.id}"
      expect(response).to have_http_status(:no_content)
      expect(Audience.find_by(id: audience.id)).to be_nil
    end
  end

  describe "POST /api/clients/:client_id/audiences/seed" do
    it "creates sample audiences" do
      post "/api/clients/#{api_client.id}/audiences/seed"
      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to be_an(Array)
      expect(response.parsed_body.length).to be > 0
    end
  end
end
