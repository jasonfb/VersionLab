require "rails_helper"

RSpec.describe "Api::AiServices", type: :request do
  include_context "api authenticated user"

  describe "GET /api/ai_services" do
    it "returns only services with configured keys by default" do
      service_with_key = create(:ai_service)
      create(:ai_key, ai_service: service_with_key)
      service_without_key = create(:ai_service)

      get "/api/ai_services"
      expect(response).to have_http_status(:ok)

      slugs = response.parsed_body.map { |s| s["slug"] }
      expect(slugs).to include(service_with_key.slug)
      expect(slugs).not_to include(service_without_key.slug)
    end

    it "returns all services when ?all is set" do
      service = create(:ai_service)
      get "/api/ai_services", params: { all: true }
      expect(response).to have_http_status(:ok)

      slugs = response.parsed_body.map { |s| s["slug"] }
      expect(slugs).to include(service.slug)
    end

    it "includes models for each service" do
      service = create(:ai_service)
      create(:ai_key, ai_service: service)
      model = create(:ai_model, ai_service: service)

      get "/api/ai_services"
      models = response.parsed_body.first["models"]
      expect(models.first["id"]).to eq(model.id)
      expect(models.first).to have_key("for_text")
    end
  end
end
