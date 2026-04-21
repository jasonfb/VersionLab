require "rails_helper"

RSpec.describe "Api::Assets", type: :request do
  include_context "api authenticated user"

  describe "GET /api/assets" do
    it "returns assets for the current client" do
      asset = create(:asset, client: client, name: "logo.png")
      get "/api/assets"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["name"]).to eq("logo.png")
    end
  end

  describe "DELETE /api/assets/:id" do
    it "deletes the asset" do
      asset = create(:asset, client: client)
      delete "/api/assets/#{asset.id}"
      expect(response).to have_http_status(:no_content)
    end
  end
end
