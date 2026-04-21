require "rails_helper"

RSpec.describe "Api::PaymentMethods", type: :request do
  include_context "api authenticated user"

  describe "GET /api/payment_methods" do
    it "returns payment methods for the account" do
      pm = create(:payment_method, account: account, card_brand: "visa", card_last4: "4242")
      get "/api/payment_methods"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["card_last4"]).to eq("4242")
      expect(response.parsed_body.first["display_name"]).to eq("Visa ending in 4242")
    end

    it "requires billing access" do
      account_user.update!(is_owner: false, is_admin: false, is_billing_admin: false)
      get "/api/payment_methods"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/payment_methods/:id/set_default" do
    it "sets the payment method as default" do
      pm1 = create(:payment_method, account: account, is_default: true)
      pm2 = create(:payment_method, account: account, is_default: false)
      post "/api/payment_methods/#{pm2.id}/set_default"
      expect(response).to have_http_status(:ok)
      expect(pm2.reload.is_default).to be true
      expect(pm1.reload.is_default).to be false
    end
  end

  describe "DELETE /api/payment_methods/:id" do
    it "deletes and detaches from Stripe" do
      pm = create(:payment_method, account: account)
      allow(Stripe::PaymentMethod).to receive(:detach)
      delete "/api/payment_methods/#{pm.id}"
      expect(response).to have_http_status(:ok)
      expect(PaymentMethod.find_by(id: pm.id)).to be_nil
    end

    it "promotes new default when deleting the default" do
      pm1 = create(:payment_method, account: account, is_default: true)
      pm2 = create(:payment_method, account: account, is_default: false)
      allow(Stripe::PaymentMethod).to receive(:detach)
      delete "/api/payment_methods/#{pm1.id}"
      expect(pm2.reload.is_default).to be true
    end
  end
end
