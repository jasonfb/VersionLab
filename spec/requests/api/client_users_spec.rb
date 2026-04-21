require "rails_helper"

RSpec.describe "Api::ClientUsers", type: :request do
  include_context "api authenticated user"

  let(:api_client) { create(:client, account: account) }

  describe "GET /api/clients/:client_id/client_users" do
    it "returns account users with assignment status" do
      get "/api/clients/#{api_client.id}/client_users"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["always_has_access"]).to be true # owner
    end

    it "forbids non-admin users" do
      account_user.update!(is_owner: false, is_admin: false)
      get "/api/clients/#{api_client.id}/client_users"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/clients/:client_id/client_users" do
    it "assigns a user to the client" do
      member = create(:user)
      create(:account_user, account: account, user: member)
      post "/api/clients/#{api_client.id}/client_users", params: { user_id: member.id }
      expect(response).to have_http_status(:created)
    end
  end

  describe "DELETE /api/clients/:client_id/client_users/:id" do
    it "unassigns a user from the client" do
      member = create(:user)
      create(:account_user, account: account, user: member)
      cu = create(:client_user, client: api_client, user: member)
      delete "/api/clients/#{api_client.id}/client_users/#{cu.id}"
      expect(response).to have_http_status(:no_content)
    end
  end
end
