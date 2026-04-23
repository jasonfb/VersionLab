require 'rails_helper'

RSpec.describe "Api::EmailDocuments", type: :request do
  include_context "api authenticated user"

  let(:template) { create(:email_template, client: client) }
  let(:email) { create(:email, client: client, email_template: template) }

  describe "GET /api/clients/:client_id/emails/:email_id/email_documents" do
    it "returns email documents" do
      doc = email.email_documents.create!(display_name: "test.pdf")
      doc.file.attach(io: StringIO.new("content"), filename: "test.pdf", content_type: "application/pdf")

      get "/api/clients/#{client.id}/emails/#{email.id}/email_documents"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.size).to eq(1)
      expect(response.parsed_body.first["display_name"]).to eq("test.pdf")
    end
  end

  describe "POST /api/clients/:client_id/emails/:email_id/email_documents" do
    it "creates a document with file upload" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("PDF content"),
        "application/pdf",
        true,
        original_filename: "brief.pdf"
      )
      post "/api/clients/#{client.id}/emails/#{email.id}/email_documents",
           params: { file: file }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["display_name"]).to eq("brief.pdf")
    end

    it "returns 422 without file" do
      post "/api/clients/#{client.id}/emails/#{email.id}/email_documents"
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /api/clients/:client_id/emails/:email_id/email_documents/:id" do
    it "destroys the document" do
      doc = email.email_documents.create!(display_name: "old.pdf")
      doc.file.attach(io: StringIO.new("content"), filename: "old.pdf", content_type: "application/pdf")

      delete "/api/clients/#{client.id}/emails/#{email.id}/email_documents/#{doc.id}"
      expect(response).to have_http_status(:no_content)
      expect(EmailDocument.find_by(id: doc.id)).to be_nil
    end
  end
end
