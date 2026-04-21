require "rails_helper"

RSpec.describe "Api::TemplateVariables", type: :request do
  include_context "api authenticated user"

  let(:api_client) { create(:client, account: account) }
  let(:template) { create(:email_template, client: api_client) }
  let(:section) { create(:email_template_section, email_template: template, position: 1, name: "1") }

  describe "GET sections/:section_id/variables" do
    it "returns variables for the section" do
      var = create(:template_variable, email_template_section: section, name: "headline",
                   variable_type: "text", default_value: "Hello", position: 1)
      get "/api/clients/#{api_client.id}/email_templates/#{template.id}/sections/#{section.id}/variables"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["name"]).to eq("headline")
    end
  end

  describe "POST sections/:section_id/variables" do
    it "creates a variable" do
      post "/api/clients/#{api_client.id}/email_templates/#{template.id}/sections/#{section.id}/variables",
           params: { variable: { name: "subhead", variable_type: "text", default_value: "Sub" } }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["name"]).to eq("subhead")
    end
  end

  describe "PATCH sections/:section_id/variables/:id" do
    it "updates the variable" do
      var = create(:template_variable, email_template_section: section, name: "headline",
                   variable_type: "text", default_value: "Hello", position: 1)
      patch "/api/clients/#{api_client.id}/email_templates/#{template.id}/sections/#{section.id}/variables/#{var.id}",
            params: { variable: { slot_role: "headline" } }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["slot_role"]).to eq("headline")
    end
  end

  describe "DELETE sections/:section_id/variables/:id" do
    it "deletes the variable" do
      var = create(:template_variable, email_template_section: section, name: "headline",
                   variable_type: "text", default_value: "Hello", position: 1)
      delete "/api/clients/#{api_client.id}/email_templates/#{template.id}/sections/#{section.id}/variables/#{var.id}"
      expect(response).to have_http_status(:no_content)
    end
  end
end
