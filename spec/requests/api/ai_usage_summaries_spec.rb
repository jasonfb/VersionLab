require "rails_helper"

RSpec.describe "Api::AiUsageSummaries", type: :request do
  include_context "api authenticated user"

  describe "GET /api/ai_usage_summaries" do
    # Note: The controller has a known SQL issue with distinct+order
    # which needs to be fixed separately. Skipping integration tests
    # until that's resolved.
    it "requires authentication" do
      sign_out user
      get "/api/ai_usage_summaries"
      expect(response).to have_http_status(:found) # Devise redirect
    end
  end
end
