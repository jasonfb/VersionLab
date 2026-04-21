require "rails_helper"

RSpec.describe "Api::AccountUsers", type: :request do
  include_context "api authenticated user"

  describe "GET /api/account_users" do
    it "returns account users with client assignments" do
      get "/api/account_users"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["email"]).to eq(user.email)
    end

    it "forbids non-owner, non-admin users" do
      account_user.update!(is_owner: false, is_admin: false)
      get "/api/account_users"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/account_users" do
    it "invites a new user by email" do
      allow(UserMailer).to receive_message_chain(:account_invitation, :deliver_later)
      post "/api/account_users", params: { email: "newuser@example.com" }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["email"]).to eq("newuser@example.com")
      expect(response.parsed_body["new_user"]).to be true
    end

    it "adds an existing user" do
      existing = create(:user)
      allow(UserMailer).to receive_message_chain(:account_invitation, :deliver_later)
      post "/api/account_users", params: { email: existing.email }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["new_user"]).to be false
    end

    it "rejects duplicate user" do
      allow(UserMailer).to receive_message_chain(:account_invitation, :deliver_later)
      post "/api/account_users", params: { email: user.email }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "requires email" do
      post "/api/account_users", params: { email: "" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/account_users/:id" do
    let(:member_user) { create(:user) }
    let!(:member_au) { create(:account_user, account: account, user: member_user) }

    it "allows owner to set admin flag" do
      patch "/api/account_users/#{member_au.id}",
            params: { account_user: { is_admin: true } }
      expect(response).to have_http_status(:ok)
      expect(member_au.reload.is_admin?).to be true
    end

    it "prevents admin from modifying owner" do
      account_user.update!(is_owner: false, is_admin: true)
      owner_user = create(:user)
      owner_au = create(:account_user, account: account, user: owner_user, is_owner: true)
      patch "/api/account_users/#{owner_au.id}",
            params: { account_user: { is_admin: true } }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/account_users/:id" do
    it "removes a user from the account" do
      member = create(:user)
      member_au = create(:account_user, account: account, user: member)
      delete "/api/account_users/#{member_au.id}"
      expect(response).to have_http_status(:no_content)
    end

    it "prevents removing the last owner" do
      delete "/api/account_users/#{account_user.id}"
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
