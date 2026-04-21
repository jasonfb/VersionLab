require 'rails_helper'

RSpec.describe "Api::EmailAutolinkSettings", type: :request do
  include_context "api authenticated user"

  let(:template) { create(:email_template, client: client) }
  let(:section) { create(:email_template_section, email_template: template) }
  let!(:variable) { create(:template_variable, email_template_section: section, slot_role: "subheadline") }
  let(:email) { create(:email, client: client, email_template: template) }

  describe "GET /api/clients/:client_id/emails/:email_id/autolink_settings" do
    it "returns sections with autolink settings" do
      get "/api/clients/#{client.id}/emails/#{email.id}/autolink_settings"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end
  end

  describe "PATCH /api/clients/:client_id/emails/:email_id/autolink_settings/:section_id" do
    it "creates or updates an autolink setting for a section" do
      patch "/api/clients/#{client.id}/emails/#{email.id}/autolink_settings/#{section.id}",
            params: { autolink_setting: { autolink_mode: "link_relevant_text", link_mode: "user_url", url: "https://example.com" } }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["autolink_mode"]).to eq("link_relevant_text")
      expect(response.parsed_body["url"]).to eq("https://example.com")
    end

    it "updates an existing setting" do
      setting = email.email_section_autolink_settings.create!(
        email_template_section: section,
        autolink_mode: "none"
      )

      patch "/api/clients/#{client.id}/emails/#{email.id}/autolink_settings/#{section.id}",
            params: { autolink_setting: { autolink_mode: "link_relevant_text" } }

      expect(response).to have_http_status(:ok)
      setting.reload
      expect(setting.autolink_mode).to eq("link_relevant_text")
    end
  end
end
