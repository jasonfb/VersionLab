require "rails_helper"

RSpec.describe "Api::Subscriptions", type: :request do
  include_context "api authenticated user"

  describe "GET /api/subscription" do
    it "returns subscription details and tiers" do
      tier = create(:subscription_tier, slug: "standard")
      create(:subscription, account: account, subscription_tier: tier)

      get "/api/subscription"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json["subscription"]).to be_a(Hash)
      expect(json["subscription"]["tier_slug"]).to eq("standard")
      expect(json["subscription"]["tokens"]).to be_a(Hash)
      expect(json["tiers"]).to be_an(Array)
    end

    it "returns nil subscription when none exists" do
      get "/api/subscription"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["subscription"]).to be_nil
    end
  end

  describe "POST /api/subscription/create_payment_intent" do
    it "requires billing access" do
      account_user.update!(is_owner: false, is_admin: false, is_billing_admin: false)
      tier = create(:subscription_tier, slug: "pro")
      post "/api/subscription/create_payment_intent",
           params: { tier_slug: "pro", billing_interval: "monthly" }
      expect(response).to have_http_status(:forbidden)
    end

    it "rejects invalid billing interval" do
      tier = create(:subscription_tier, slug: "pro")
      post "/api/subscription/create_payment_intent",
           params: { tier_slug: "pro", billing_interval: "biweekly" }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
