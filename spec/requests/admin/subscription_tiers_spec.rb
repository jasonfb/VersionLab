require 'rails_helper'

RSpec.describe "Admin::SubscriptionTiers", type: :request do
  include_context "admin authenticated user"

  let!(:tier) { create(:subscription_tier, name: "Standard", slug: "standard") }

  describe "GET /admin/subscription_tiers" do
    it "renders the index" do
      get admin_subscription_tiers_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /admin/subscription_tiers/new" do
    it "renders the new form" do
      get new_admin_subscription_tier_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/subscription_tiers" do
    it "creates a tier" do
      post admin_subscription_tiers_path, as: :turbo_stream, params: {
        subscription_tier: { name: "Premium", slug: "premium", monthly_price_cents: 9900,
                            annual_price_cents: 99900, monthly_token_allotment: 5000,
                            overage_cents_per_1000_tokens: 500, position: 2 }
      }
      expect(SubscriptionTier.find_by(slug: "premium")).to be_present
    end
  end

  describe "GET /admin/subscription_tiers/:id" do
    it "redirects to edit" do
      get admin_subscription_tier_path(tier)
      expect(response).to redirect_to(edit_admin_subscription_tier_path(tier))
    end
  end

  describe "GET /admin/subscription_tiers/:id/edit" do
    it "renders the edit form" do
      get edit_admin_subscription_tier_path(tier)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /admin/subscription_tiers/:id" do
    it "updates the tier" do
      patch admin_subscription_tier_path(tier), params: { subscription_tier: { name: "Renamed" } }, as: :turbo_stream
      tier.reload
      expect(tier.name).to eq("Renamed")
    end
  end

  describe "DELETE /admin/subscription_tiers/:id" do
    it "destroys the tier" do
      delete admin_subscription_tier_path(tier), as: :turbo_stream
      expect(SubscriptionTier.find_by(id: tier.id)).to be_nil
    end
  end
end
