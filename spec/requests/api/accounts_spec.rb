require "rails_helper"

RSpec.describe "Api::Accounts", type: :request do
  include_context "api authenticated user"

  describe "GET /api/accounts" do
    it "returns the current user context" do
      get "/api/accounts"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json["current_user_id"]).to eq(user.id)
      expect(json["current_account_id"]).to eq(account.id)
      expect(json["accounts"]).to be_an(Array)
      expect(json["accounts"].first["id"]).to eq(account.id)
      expect(json["subscription"]).to be_a(Hash)
    end

    it "includes client list" do
      get "/api/accounts"
      json = response.parsed_body
      expect(json["clients"]).to be_an(Array)
    end
  end

  describe "POST /api/switch_account" do
    it "switches the current account" do
      other_account = create(:account)
      create(:account_user, account: other_account, user: user)

      post "/api/switch_account", params: { account_id: other_account.id }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["current_account_id"]).to eq(other_account.id)
    end

    it "rejects switching to an account the user does not belong to" do
      other_account = create(:account)
      post "/api/switch_account", params: { account_id: other_account.id }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/switch_client" do
    let(:account) { create(:account, is_agency: true) }
    let(:other_client) { create(:client, account: account) }

    it "switches the current client" do
      other_client # ensure created
      post "/api/switch_client", params: { client_id: other_client.id }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["current_client_id"]).to eq(other_client.id)
    end
  end

  describe "POST /api/upgrade_to_agency" do
    it "upgrades the account to agency" do
      post "/api/upgrade_to_agency"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["is_agency"]).to be true
      expect(account.reload.is_agency?).to be true
    end

    it "returns error if already an agency" do
      account.update!(is_agency: true)
      post "/api/upgrade_to_agency"
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "forbids non-owners" do
      account_user.update!(is_owner: false, is_admin: true)
      post "/api/upgrade_to_agency"
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "when not authenticated" do
    before { sign_out user }

    it "returns 401 for unauthenticated requests" do
      get "/api/accounts"
      expect(response).to have_http_status(:found) # Devise redirects
    end
  end
end
