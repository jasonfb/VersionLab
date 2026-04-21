require 'rails_helper'

RSpec.describe "Admin::Accounts", type: :request do
  include_context "admin authenticated user"

  let!(:test_account) { create(:account, name: "Test Org") }

  describe "GET /admin/accounts" do
    it "renders the index" do
      get admin_accounts_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /admin/accounts/new" do
    it "renders the new form" do
      get new_admin_account_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/accounts" do
    it "creates an account" do
      post admin_accounts_path, params: { account: { name: "New Org" } }, as: :turbo_stream
      expect(Account.find_by(name: "New Org")).to be_present
    end
  end

  describe "GET /admin/accounts/:id" do
    it "redirects to edit" do
      get admin_account_path(test_account)
      expect(response).to redirect_to(edit_admin_account_path(test_account))
    end
  end

  describe "GET /admin/accounts/:id/edit" do
    it "renders the edit form" do
      get edit_admin_account_path(test_account)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /admin/accounts/:id" do
    it "updates the account" do
      patch admin_account_path(test_account), params: { account: { name: "Renamed" } }
      expect(response).to redirect_to(admin_accounts_path)
      test_account.reload
      expect(test_account.name).to eq("Renamed")
    end
  end

  describe "DELETE /admin/accounts/:id" do
    it "destroys the account" do
      delete admin_account_path(test_account), as: :turbo_stream
      expect(Account.find_by(id: test_account.id)).to be_nil
    end
  end

  describe "authorization" do
    it "redirects non-admin users" do
      sign_in create(:user)
      get admin_accounts_path
      expect(response).to redirect_to(root_path)
    end
  end
end
