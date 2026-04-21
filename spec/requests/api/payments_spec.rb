require "rails_helper"

RSpec.describe "Api::Payments", type: :request do
  include_context "api authenticated user"

  describe "GET /api/payments" do
    it "returns recent payments" do
      payment = create(:payment, account: account, amount_cents: 4900, description: "Monthly")
      get "/api/payments"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["amount_cents"]).to eq(4900)
    end

    it "limits to 50 records" do
      55.times { create(:payment, account: account) }
      get "/api/payments"
      expect(response.parsed_body.length).to eq(50)
    end

    it "requires billing access" do
      account_user.update!(is_owner: false, is_admin: false, is_billing_admin: false)
      get "/api/payments"
      expect(response).to have_http_status(:forbidden)
    end
  end
end
