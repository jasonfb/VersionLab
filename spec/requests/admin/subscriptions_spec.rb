require 'rails_helper'

RSpec.describe "Admin::Subscriptions", type: :request do
  include_context "admin authenticated user"

  let(:test_account) { create(:account) }
  let(:tier) { create(:subscription_tier) }
  let!(:subscription) { create(:subscription, account: test_account, subscription_tier: tier) }

  describe "GET /admin/subscriptions/:id/edit" do
    it "renders the edit form" do
      get edit_admin_subscription_path(subscription)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /admin/subscriptions/:id" do
    it "updates the token allotment override" do
      patch admin_subscription_path(subscription),
            params: { subscription: { monthly_token_allotment_override: 5000 } }
      expect(response).to redirect_to(edit_admin_account_path(test_account))
      subscription.reload
      expect(subscription.monthly_token_allotment_override).to eq(5000)
    end
  end
end
