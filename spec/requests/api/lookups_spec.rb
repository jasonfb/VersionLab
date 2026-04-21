require "rails_helper"

RSpec.describe "Api::Lookups", type: :request do
  include_context "api authenticated user"

  describe "GET /api/lookups" do
    it "returns all lookup data" do
      create(:geography, name: "North America")
      create(:industry, name: "Technology")

      get "/api/lookups"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      %w[organization_types industries primary_audiences tone_rules geographies].each do |key|
        expect(json).to have_key(key)
        expect(json[key]).to be_an(Array)
      end
    end
  end
end
