require 'rails_helper'

RSpec.describe "Admin::AiKeys", type: :request do
  include_context "admin authenticated user"

  let(:ai_service) { create(:ai_service) }
  let!(:ai_key) { create(:ai_key, ai_service: ai_service) }

  describe "GET /admin/ai_keys" do
    it "renders the index" do
      get admin_ai_keys_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /admin/ai_keys/new" do
    it "renders the new form" do
      get new_admin_ai_key_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/ai_keys" do
    it "creates an AI key" do
      new_service = create(:ai_service)
      post admin_ai_keys_path, as: :turbo_stream,
           params: { ai_key: { ai_service_id: new_service.id, api_key: "sk-new-key" } }
      expect(AiKey.find_by(ai_service_id: new_service.id)).to be_present
    end
  end

  describe "GET /admin/ai_keys/:id" do
    it "redirects to edit" do
      get admin_ai_key_path(ai_key)
      expect(response).to redirect_to(edit_admin_ai_key_path(ai_key))
    end
  end

  describe "GET /admin/ai_keys/:id/edit" do
    it "renders the edit form" do
      get edit_admin_ai_key_path(ai_key)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /admin/ai_keys/:id" do
    it "updates the key" do
      patch admin_ai_key_path(ai_key), params: { ai_key: { api_key: "sk-updated" } }, as: :turbo_stream
      ai_key.reload
      expect(ai_key.api_key).to eq("sk-updated")
    end
  end

  describe "DELETE /admin/ai_keys/:id" do
    it "destroys the key" do
      delete admin_ai_key_path(ai_key), as: :turbo_stream
      expect(AiKey.find_by(id: ai_key.id)).to be_nil
    end
  end
end
