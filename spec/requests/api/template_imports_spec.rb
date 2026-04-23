require 'rails_helper'

RSpec.describe "Api::TemplateImports", type: :request do
  include_context "api authenticated user"

  describe "POST /api/clients/:client_id/template_imports" do
    let(:zip_file) do
      Rack::Test::UploadedFile.new(
        StringIO.new("PK\x03\x04fake-zip-content"),
        "application/zip",
        true,
        original_filename: "template.zip"
      )
    end

    it "returns 422 when name is blank" do
      post "/api/clients/#{client.id}/template_imports",
           params: { name: "", import_type: "bundled", file: zip_file }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("Name is required")
    end

    it "returns 422 for invalid import_type" do
      post "/api/clients/#{client.id}/template_imports",
           params: { name: "Test", import_type: "invalid", file: zip_file }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("Import type must be bundled or external")
    end

    it "returns 422 when file is missing" do
      post "/api/clients/#{client.id}/template_imports",
           params: { name: "Test", import_type: "bundled" }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 422 for non-ZIP bundled import" do
      html_file = Rack::Test::UploadedFile.new(
        StringIO.new("<html></html>"),
        "text/html",
        false,
        original_filename: "template.html"
      )
      post "/api/clients/#{client.id}/template_imports",
           params: { name: "Test", import_type: "bundled", file: html_file }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include(/ZIP/)
    end

    it "creates a template import for valid external HTML" do
      allow(TemplateImportJob).to receive(:perform_later)

      html_file = Rack::Test::UploadedFile.new(
        StringIO.new("<html><body>Hello</body></html>"),
        "text/html",
        false,
        original_filename: "template.html"
      )
      post "/api/clients/#{client.id}/template_imports",
           params: { name: "External Import", import_type: "external", file: html_file }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["state"]).to eq("pending")
      expect(TemplateImportJob).to have_received(:perform_later)
    end
  end
end
