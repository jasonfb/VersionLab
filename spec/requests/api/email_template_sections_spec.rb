require "rails_helper"

RSpec.describe "Api::EmailTemplateSections", type: :request do
  include_context "api authenticated user"

  let(:api_client) { create(:client, account: account) }
  let(:template) { create(:email_template, client: api_client) }

  describe "GET /api/clients/:client_id/email_templates/:email_template_id/sections" do
    it "returns sections for the template" do
      section = create(:email_template_section, email_template: template, position: 1, name: "Header")
      get "/api/clients/#{api_client.id}/email_templates/#{template.id}/sections"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["name"]).to eq("Header")
    end
  end

  describe "POST /api/clients/:client_id/email_templates/:email_template_id/sections" do
    it "creates a section" do
      post "/api/clients/#{api_client.id}/email_templates/#{template.id}/sections",
           params: { section: { name: "Body", element_selector: "div.body" } }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["name"]).to eq("Body")
    end

    it "auto-names subsections" do
      parent = create(:email_template_section, email_template: template, position: 1, name: "1")
      post "/api/clients/#{api_client.id}/email_templates/#{template.id}/sections",
           params: { section: { parent_id: parent.id } }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["name"]).to eq("1A")
    end
  end

  describe "PATCH /api/clients/:client_id/email_templates/:email_template_id/sections/:id" do
    it "updates the section" do
      section = create(:email_template_section, email_template: template, position: 1, name: "Old")
      patch "/api/clients/#{api_client.id}/email_templates/#{template.id}/sections/#{section.id}",
            params: { section: { name: "New" } }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["name"]).to eq("New")
    end
  end

  describe "DELETE /api/clients/:client_id/email_templates/:email_template_id/sections/:id" do
    it "deletes the section and reorders" do
      s1 = create(:email_template_section, email_template: template, position: 1, name: "1")
      s2 = create(:email_template_section, email_template: template, position: 2, name: "2")
      delete "/api/clients/#{api_client.id}/email_templates/#{template.id}/sections/#{s1.id}"
      expect(response).to have_http_status(:no_content)
      expect(s2.reload.position).to eq(1)
    end
  end
end
