require "rails_helper"

RSpec.describe "Api::EmailTemplates", type: :request do
  include_context "api authenticated user"

  let(:api_client) { create(:client, account: account) }

  describe "GET /api/clients/:client_id/email_templates" do
    it "returns templates for the client" do
      template = create(:email_template, client: api_client)
      get "/api/clients/#{api_client.id}/email_templates"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["id"]).to eq(template.id)
    end
  end

  describe "GET /api/clients/:client_id/email_templates/:id" do
    it "returns the template with sections" do
      template = create(:email_template, client: api_client)
      get "/api/clients/#{api_client.id}/email_templates/#{template.id}"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json["id"]).to eq(template.id)
      expect(json["raw_source_html"]).to be_present
      expect(json).to have_key("sections")
    end
  end

  describe "POST /api/clients/:client_id/email_templates" do
    it "creates a template" do
      post "/api/clients/#{api_client.id}/email_templates",
           params: { email_template: { name: "New Template", raw_source_html: "<p>Hello</p>" } }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["name"]).to eq("New Template")
    end
  end

  describe "PATCH /api/clients/:client_id/email_templates/:id" do
    it "updates the template" do
      template = create(:email_template, client: api_client)
      patch "/api/clients/#{api_client.id}/email_templates/#{template.id}",
            params: { email_template: { name: "Renamed" } }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["name"]).to eq("Renamed")
    end
  end

  describe "POST /api/clients/:client_id/email_templates/:id/reset" do
    it "resets template to original" do
      template = create(:email_template, client: api_client,
                        raw_source_html: "<p>Modified</p>",
                        original_raw_source_html: "<p>Original</p>")
      post "/api/clients/#{api_client.id}/email_templates/#{template.id}/reset"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["raw_source_html"]).to eq("<p>Original</p>")
    end

    it "resets template to blank" do
      template = create(:email_template, client: api_client,
                        raw_source_html: "<p>Something</p>")
      post "/api/clients/#{api_client.id}/email_templates/#{template.id}/reset",
           params: { mode: "blank" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE /api/clients/:client_id/email_templates/:id" do
    it "deletes the template" do
      template = create(:email_template, client: api_client)
      delete "/api/clients/#{api_client.id}/email_templates/#{template.id}"
      expect(response).to have_http_status(:no_content)
    end
  end
end
