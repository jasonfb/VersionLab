require "rails_helper"

RSpec.describe "Api::Emails", type: :request do
  include_context "api authenticated user"

  let(:api_client) { create(:client, account: account) }
  let(:template) { create(:email_template, client: api_client) }
  let(:audience) { create(:audience, client: api_client) }
  let(:ai_service) { create(:ai_service) }
  let(:ai_model) { create(:ai_model, ai_service: ai_service) }
  let!(:ai_key) { create(:ai_key, ai_service: ai_service) }

  describe "GET /api/clients/:client_id/emails" do
    it "returns emails for the client" do
      email = create(:email, client: api_client, email_template: template)
      get "/api/clients/#{api_client.id}/emails"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["id"]).to eq(email.id)
    end
  end

  describe "GET /api/clients/:client_id/emails/:id" do
    it "returns the email" do
      email = create(:email, client: api_client, email_template: template)
      get "/api/clients/#{api_client.id}/emails/#{email.id}"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(email.id)
      expect(response.parsed_body["email_template_name"]).to eq(template.name)
    end
  end

  describe "POST /api/clients/:client_id/emails" do
    it "creates an email" do
      post "/api/clients/#{api_client.id}/emails",
           params: { email: {
             email_template_id: template.id,
             ai_service_id: ai_service.id,
             ai_model_id: ai_model.id,
             audience_ids: [audience.id]
           } }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["state"]).to eq("setup")
      expect(response.parsed_body["audience_ids"]).to include(audience.id)
    end
  end

  describe "PATCH /api/clients/:client_id/emails/:id" do
    it "updates the email" do
      email = create(:email, client: api_client, email_template: template)
      patch "/api/clients/#{api_client.id}/emails/#{email.id}",
            params: { email: { context: "Holiday campaign" } }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["context"]).to eq("Holiday campaign")
    end
  end

  describe "DELETE /api/clients/:client_id/emails/:id" do
    it "deletes the email" do
      email = create(:email, client: api_client, email_template: template)
      delete "/api/clients/#{api_client.id}/emails/#{email.id}"
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "POST /api/clients/:client_id/emails/:id/run" do
    it "submits the email for AI generation" do
      allow(EmailJob).to receive(:perform_later)
      email = create(:email, client: api_client, email_template: template,
                     ai_service: ai_service, ai_model: ai_model)
      email.audiences << audience

      post "/api/clients/#{api_client.id}/emails/#{email.id}/run"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["state"]).to eq("pending")
      expect(EmailJob).to have_received(:perform_later).with(email.id)
    end

    it "rejects run without AI service" do
      email = create(:email, client: api_client, email_template: template)
      email.audiences << audience
      post "/api/clients/#{api_client.id}/emails/#{email.id}/run"
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects run without audiences" do
      email = create(:email, client: api_client, email_template: template,
                     ai_service: ai_service, ai_model: ai_model)
      post "/api/clients/#{api_client.id}/emails/#{email.id}/run"
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects run when not in setup state" do
      allow(EmailJob).to receive(:perform_later)
      email = create(:email, client: api_client, email_template: template,
                     ai_service: ai_service, ai_model: ai_model, state: "pending")
      email.audiences << audience
      post "/api/clients/#{api_client.id}/emails/#{email.id}/run"
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/clients/:client_id/emails/:id/summarize" do
    it "triggers AI summary generation" do
      allow(EmailSummaryJob).to receive(:perform_later)
      email = create(:email, client: api_client, email_template: template)
      post "/api/clients/#{api_client.id}/emails/#{email.id}/summarize"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["ai_summary_state"]).to eq("generating")
      expect(EmailSummaryJob).to have_received(:perform_later).with(email.id)
    end
  end

  describe "GET /api/clients/:client_id/emails/:id/results" do
    it "returns results grouped by audience" do
      email = create(:email, client: api_client, email_template: template)
      email.audiences << audience
      get "/api/clients/#{api_client.id}/emails/#{email.id}/results"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["audiences"]).to be_an(Array)
      expect(response.parsed_body["audiences"].first["id"]).to eq(audience.id)
    end
  end

  describe "POST /api/clients/:client_id/emails/:id/reject" do
    let(:email) do
      create(:email, client: api_client, email_template: template,
             ai_service: ai_service, ai_model: ai_model, state: "merged")
    end

    before { email.audiences << audience }

    it "rejects a version and triggers regeneration" do
      allow(EmailJob).to receive(:perform_later)
      version = create(:email_version, email: email, audience: audience,
                       ai_service: ai_service, ai_model: ai_model, state: "active")

      post "/api/clients/#{api_client.id}/emails/#{email.id}/reject",
           params: { audience_id: audience.id, rejection_comment: "Too formal" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["state"]).to eq("regenerating")
      expect(EmailJob).to have_received(:perform_later)
    end

    it "rejects without rejection comment" do
      create(:email_version, email: email, audience: audience,
             ai_service: ai_service, ai_model: ai_model, state: "active")
      post "/api/clients/#{api_client.id}/emails/#{email.id}/reject",
           params: { audience_id: audience.id }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects when not in merged state" do
      email.update!(state: "setup")
      post "/api/clients/#{api_client.id}/emails/#{email.id}/reject",
           params: { audience_id: audience.id, rejection_comment: "Bad" }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects when no active version exists" do
      post "/api/clients/#{api_client.id}/emails/#{email.id}/reject",
           params: { audience_id: audience.id, rejection_comment: "Bad" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/clients/:client_id/emails/:id/export" do
    it "returns a ZIP file" do
      email = create(:email, client: api_client, email_template: template)
      email.audiences << audience
      section = create(:email_template_section, email_template: template)
      variable = create(:template_variable, email_template_section: section)
      version = create(:email_version, email: email, audience: audience,
                       ai_service: ai_service, ai_model: ai_model, state: "active")
      create(:email_version_variable, email_version: version,
             template_variable: variable, value: "Exported text")

      get "/api/clients/#{api_client.id}/emails/#{email.id}/export"
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/zip")
    end
  end

  describe "GET /api/clients/:client_id/emails/:id/preview" do
    it "renders HTML preview for an audience" do
      email = create(:email, client: api_client, email_template: template)
      email.audiences << audience
      section = create(:email_template_section, email_template: template)
      variable = create(:template_variable, email_template_section: section)
      version = create(:email_version, email: email, audience: audience,
                       ai_service: ai_service, ai_model: ai_model, state: "active")
      create(:email_version_variable, email_version: version,
             template_variable: variable, value: "Preview text")

      get "/api/clients/#{api_client.id}/emails/#{email.id}/preview",
          params: { audience_id: audience.id }
      expect(response).to have_http_status(:ok)
    end

    it "returns fallback when no active version" do
      email = create(:email, client: api_client, email_template: template)
      email.audiences << audience

      get "/api/clients/#{api_client.id}/emails/#{email.id}/preview",
          params: { audience_id: audience.id }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No active version")
    end
  end

  describe "POST /api/clients/:client_id/emails/:id/run without API key" do
    it "rejects when no API key for service" do
      ai_key.destroy!
      email = create(:email, client: api_client, email_template: template,
                     ai_service: ai_service, ai_model: ai_model)
      email.audiences << audience
      post "/api/clients/#{api_client.id}/emails/#{email.id}/run"
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to include("No API key")
    end
  end
end
