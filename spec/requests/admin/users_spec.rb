require 'rails_helper'

RSpec.describe "Admin::Users", type: :request do
  include_context "admin authenticated user"

  let!(:test_user) { create(:user, email: "testuser@example.com", name: "Test User") }

  describe "GET /admin/users" do
    it "renders the index" do
      get admin_users_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /admin/users/new" do
    it "renders the new form" do
      get new_admin_user_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /admin/users/:id" do
    it "redirects to edit" do
      get admin_user_path(test_user)
      expect(response).to redirect_to(edit_admin_user_path(test_user))
    end
  end

  describe "GET /admin/users/:id/edit" do
    it "renders the edit form" do
      get edit_admin_user_path(test_user)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /admin/users/:id" do
    it "updates the user" do
      patch admin_user_path(test_user), params: { user: { name: "Updated Name" } }, as: :turbo_stream
      test_user.reload
      expect(test_user.name).to eq("Updated Name")
    end
  end

  describe "POST /admin/users" do
    it "renders error on invalid user (admin can only set email/name)" do
      post admin_users_path, as: :turbo_stream,
           params: { user: { email: "", name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /admin/users/:id" do
    it "destroys the user" do
      delete admin_user_path(test_user), as: :turbo_stream
      expect(User.find_by(id: test_user.id)).to be_nil
    end
  end
end
