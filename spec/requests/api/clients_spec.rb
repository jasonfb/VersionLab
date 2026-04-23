require "rails_helper"

RSpec.describe "Api::Clients", type: :request do
  include_context "api authenticated user"

  describe "GET /api/clients" do
    it "returns accessible clients" do
      visible_client = create(:client, account: account)
      get "/api/clients"
      expect(response).to have_http_status(:ok)

      names = response.parsed_body.map { |c| c["name"] }
      expect(names).to include(visible_client.name)
    end
  end

  describe "POST /api/clients" do
    it "creates a new client" do
      post "/api/clients", params: { client: { name: "New Client" } }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["name"]).to eq("New Client")
    end

    it "rejects blank name" do
      post "/api/clients", params: { client: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /api/clients/:id" do
    it "updates a client" do
      c = create(:client, account: account)
      patch "/api/clients/#{c.id}", params: { client: { name: "Renamed" } }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["name"]).to eq("Renamed")
    end
  end
end
