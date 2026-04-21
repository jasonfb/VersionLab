require 'rails_helper'

RSpec.describe "Admin::AccountUsers", type: :request do
  include_context "admin authenticated user"

  let(:test_account) { create(:account) }
  let(:member_user) { create(:user) }
  let!(:account_user) { create(:account_user, account: test_account, user: member_user) }

  describe "GET /admin/accounts/:account_id/account_users" do
    it "renders the index" do
      get admin_account_account_users_path(test_account)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /admin/accounts/:account_id/account_users/new" do
    it "renders the new form" do
      get new_admin_account_account_user_path(test_account)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/accounts/:account_id/account_users" do
    it "creates an account user" do
      new_user = create(:user)
      post admin_account_account_users_path(test_account), as: :turbo_stream,
           params: { account_user: { user_id: new_user.id, is_owner: false } }
      expect(test_account.account_users.where(user: new_user)).to exist
    end
  end

  describe "GET /admin/accounts/:account_id/account_users/:id" do
    it "redirects to edit" do
      get admin_account_account_user_path(test_account, account_user)
      expect(response).to redirect_to(edit_admin_account_account_user_path(test_account, account_user))
    end
  end

  describe "GET /admin/accounts/:account_id/account_users/:id/edit" do
    it "renders the edit form" do
      get edit_admin_account_account_user_path(test_account, account_user)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /admin/accounts/:account_id/account_users/:id" do
    it "updates the account user" do
      patch admin_account_account_user_path(test_account, account_user), as: :turbo_stream,
            params: { account_user: { is_owner: true } }
      account_user.reload
      expect(account_user.is_owner).to be true
    end
  end

  describe "DELETE /admin/accounts/:account_id/account_users/:id" do
    it "destroys the account user" do
      delete admin_account_account_user_path(test_account, account_user), as: :turbo_stream
      expect(AccountUser.find_by(id: account_user.id)).to be_nil
    end
  end
end
