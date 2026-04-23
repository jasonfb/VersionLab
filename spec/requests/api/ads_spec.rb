require "rails_helper"

RSpec.describe "Api::Ads", type: :request do
  include_context "api authenticated user"

  let(:api_client) { create(:client, account: account) }
  let(:audience) { create(:audience, client: api_client) }
  let(:ai_service) { create(:ai_service) }
  let(:ai_model) { create(:ai_model, ai_service: ai_service) }
  let!(:ai_key) { create(:ai_key, ai_service: ai_service) }

  describe "GET /api/clients/:client_id/ads" do
    it "returns ads for the client" do
      ad = create(:ad, client: api_client)
      get "/api/clients/#{api_client.id}/ads"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["id"]).to eq(ad.id)
    end
  end

  describe "GET /api/clients/:client_id/ads/:id" do
    it "returns the ad" do
      ad = create(:ad, client: api_client)
      get "/api/clients/#{api_client.id}/ads/#{ad.id}"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["name"]).to eq(ad.name)
    end
  end

  describe "POST /api/clients/:client_id/ads" do
    it "creates an ad" do
      post "/api/clients/#{api_client.id}/ads", params: { name: "Summer Ad" }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["name"]).to eq("Summer Ad")
    end

    it "defaults name to Untitled Ad" do
      post "/api/clients/#{api_client.id}/ads"
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["name"]).to eq("Untitled Ad")
    end
  end

  describe "PATCH /api/clients/:client_id/ads/:id" do
    it "updates ad settings" do
      ad = create(:ad, client: api_client)
      patch "/api/clients/#{api_client.id}/ads/#{ad.id}",
            params: { ad: { name: "Renamed Ad", background_color: "#FF0000" } }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["name"]).to eq("Renamed Ad")
      expect(response.parsed_body["background_color"]).to eq("#FF0000")
    end

    it "updates audiences" do
      ad = create(:ad, client: api_client)
      patch "/api/clients/#{api_client.id}/ads/#{ad.id}",
            params: { ad: { audience_ids: [audience.id] } }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["audience_ids"]).to include(audience.id)
    end
  end

  describe "DELETE /api/clients/:client_id/ads/:id" do
    it "deletes the ad" do
      ad = create(:ad, client: api_client)
      delete "/api/clients/#{api_client.id}/ads/#{ad.id}"
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "POST /api/clients/:client_id/ads/:id/run" do
    it "submits the ad for AI generation" do
      allow(AdJob).to receive(:perform_later)
      ad = create(:ad, client: api_client, ai_service: ai_service, ai_model: ai_model,
                  parsed_layers: [{ "type" => "text", "text" => "Hello" }])
      ad.audiences << audience

      post "/api/clients/#{api_client.id}/ads/#{ad.id}/run"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["state"]).to eq("pending")
      expect(AdJob).to have_received(:perform_later).with(ad.id)
    end

    it "rejects run without audiences" do
      ad = create(:ad, client: api_client, ai_service: ai_service, ai_model: ai_model,
                  parsed_layers: [{ "type" => "text" }])
      post "/api/clients/#{api_client.id}/ads/#{ad.id}/run"
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects run without AI service" do
      ad = create(:ad, client: api_client, parsed_layers: [{ "type" => "text" }])
      ad.audiences << audience
      post "/api/clients/#{api_client.id}/ads/#{ad.id}/run"
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects run without text layers" do
      ad = create(:ad, client: api_client, ai_service: ai_service, ai_model: ai_model,
                  parsed_layers: [{ "type" => "image" }])
      ad.audiences << audience
      post "/api/clients/#{api_client.id}/ads/#{ad.id}/run"
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /api/clients/:client_id/ads/:id/classifications" do
    it "returns layer classifications" do
      ad = create(:ad, client: api_client,
                  classified_layers: [{ "id" => "1", "role" => "headline" }],
                  classifications_confirmed: true)
      get "/api/clients/#{api_client.id}/ads/#{ad.id}/classifications"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["classifications_confirmed"]).to be true
    end
  end

  describe "POST /api/clients/:client_id/ads/:id/confirm_classifications" do
    it "confirms classifications" do
      ad = create(:ad, client: api_client)
      post "/api/clients/#{api_client.id}/ads/#{ad.id}/confirm_classifications",
           params: { classified_layers: [{ id: "1", role: "headline", type: "text" }] }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["classifications_confirmed"]).to be true
    end

    it "rejects missing layers" do
      ad = create(:ad, client: api_client)
      post "/api/clients/#{api_client.id}/ads/#{ad.id}/confirm_classifications"
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /api/clients/:client_id/ads/:id/results" do
    it "returns results grouped by audience" do
      ad = create(:ad, client: api_client)
      ad.audiences << audience
      get "/api/clients/#{api_client.id}/ads/#{ad.id}/results"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["audiences"]).to be_an(Array)
    end
  end

  describe "POST /api/clients/:client_id/ads/:id/ai_classify" do
    it "calls AdAiClassifyService" do
      ad = create(:ad, client: api_client,
                  parsed_layers: [{ "id" => "l1", "type" => "text", "content" => "Hi" }])
      allow_any_instance_of(AdAiClassifyService).to receive(:call).and_return(ad.parsed_layers)
      post "/api/clients/#{api_client.id}/ads/#{ad.id}/ai_classify"
      expect(response).to have_http_status(:ok)
    end

    it "returns 422 on service error" do
      ad = create(:ad, client: api_client)
      allow_any_instance_of(AdAiClassifyService).to receive(:call).and_raise(AdAiClassifyService::Error, "No layers")
      post "/api/clients/#{api_client.id}/ads/#{ad.id}/ai_classify"
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /api/clients/:client_id/ads/:id/resize" do
    let(:ad) do
      create(:ad, client: api_client, state: "setup", classifications_confirmed: true,
             width: 1080, height: 1080,
             parsed_layers: [{ "id" => "l1", "type" => "text", "content" => "Hi" }],
             classified_layers: [{ "id" => "l1", "type" => "text", "role" => "headline" }])
    end

    it "creates resizes for selected platforms" do
      resize = create(:ad_resize, ad: ad)
      allow_any_instance_of(AdResizeService).to receive(:call).and_return([resize])

      post "/api/clients/#{api_client.id}/ads/#{ad.id}/resize",
           params: { platforms: ["Facebook (Meta)"] }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["state"]).to eq("resizing")
    end

    it "rejects when classifications not confirmed" do
      ad.update!(classifications_confirmed: false)
      post "/api/clients/#{api_client.id}/ads/#{ad.id}/resize",
           params: { platforms: ["Facebook"] }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects when no platforms provided" do
      post "/api/clients/#{api_client.id}/ads/#{ad.id}/resize"
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /api/clients/:client_id/ads/:id/resizes" do
    it "returns resizes for the ad" do
      ad = create(:ad, client: api_client)
      create(:ad_resize, ad: ad, width: 728, height: 90, aspect_ratio: "728:90")
      get "/api/clients/#{api_client.id}/ads/#{ad.id}/resizes"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.size).to eq(1)
    end
  end

  describe "POST /api/clients/:client_id/ads/:id/reject" do
    let(:ad) do
      create(:ad, client: api_client, state: "merged",
             ai_service: ai_service, ai_model: ai_model,
             parsed_layers: [{ "id" => "l1", "type" => "text" }])
    end

    it "rejects a single version" do
      allow(AdJob).to receive(:perform_later)
      ad.audiences << audience
      version = create(:ad_version, ad: ad, audience: audience,
                       ai_service: ai_service, ai_model: ai_model, state: "active")

      post "/api/clients/#{api_client.id}/ads/#{ad.id}/reject",
           params: { version_id: version.id, rejection_comment: "Too generic" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["state"]).to eq("regenerating")
      expect(AdJob).to have_received(:perform_later)
    end

    it "rejects all versions for an audience" do
      allow(AdJob).to receive(:perform_later)
      ad.audiences << audience
      create(:ad_version, ad: ad, audience: audience,
             ai_service: ai_service, ai_model: ai_model, state: "active")

      post "/api/clients/#{api_client.id}/ads/#{ad.id}/reject",
           params: { audience_id: audience.id, rejection_comment: "Wrong tone" }
      expect(response).to have_http_status(:ok)
    end

    it "rejects without rejection comment" do
      post "/api/clients/#{api_client.id}/ads/#{ad.id}/reject",
           params: { version_id: "fake-id" }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects when ad not in merged state" do
      ad.update!(state: "setup")
      post "/api/clients/#{api_client.id}/ads/#{ad.id}/reject",
           params: { version_id: "fake", rejection_comment: "Bad" }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /api/clients/:client_id/ads/:id/upload_logo" do
    it "attaches a logo and adds logo layer" do
      ad = create(:ad, client: api_client, width: 1000, height: 1000,
                  parsed_layers: [{ "id" => "l1", "type" => "text", "content" => "Hi" }],
                  classified_layers: [{ "id" => "l1", "type" => "text" }])
      logo = Rack::Test::UploadedFile.new(
        StringIO.new("\x89PNG\r\n\x1a\n" + "\x00" * 100),
        "image/png", true, original_filename: "logo.png"
      )
      post "/api/clients/#{api_client.id}/ads/#{ad.id}/upload_logo", params: { logo: logo }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["has_logo"]).to be true
    end

    it "rejects non-PNG files" do
      ad = create(:ad, client: api_client)
      jpg = Rack::Test::UploadedFile.new(
        StringIO.new("fake"), "image/jpeg", true, original_filename: "logo.jpg"
      )
      post "/api/clients/#{api_client.id}/ads/#{ad.id}/upload_logo", params: { logo: jpg }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /api/clients/:client_id/ads/:id/remove_logo" do
    it "removes the logo" do
      ad = create(:ad, client: api_client,
                  parsed_layers: [{ "id" => "uploaded_logo", "type" => "image" }],
                  classified_layers: [{ "id" => "uploaded_logo", "type" => "image" }])
      delete "/api/clients/#{api_client.id}/ads/#{ad.id}/remove_logo"
      expect(response).to have_http_status(:ok)
      ad.reload
      expect(ad.parsed_layers.none? { |l| l["id"] == "uploaded_logo" }).to be true
    end
  end

  describe "GET /api/clients/:client_id/ads/:id/download_version" do
    it "returns 404 when rendered image not attached" do
      ad = create(:ad, client: api_client, ai_service: ai_service, ai_model: ai_model)
      version = create(:ad_version, ad: ad, audience: audience,
                       ai_service: ai_service, ai_model: ai_model, state: "active")
      get "/api/clients/#{api_client.id}/ads/#{ad.id}/download_version",
          params: { version_id: version.id }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/clients/:client_id/ads/:id/run missing API key" do
    it "returns 422 when no API key for the service" do
      ai_key.destroy!
      ad = create(:ad, client: api_client, ai_service: ai_service, ai_model: ai_model,
                  parsed_layers: [{ "type" => "text", "content" => "Hello" }])
      ad.audiences << audience
      post "/api/clients/#{api_client.id}/ads/#{ad.id}/run"
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("No API key")
    end
  end

  describe "PATCH /api/clients/:client_id/ads/:id update with campaign" do
    it "assigns a campaign" do
      ad = create(:ad, client: api_client)
      campaign = create(:campaign, client: api_client)
      patch "/api/clients/#{api_client.id}/ads/#{ad.id}",
            params: { ad: { campaign_id: campaign.id } }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["campaign_id"]).to eq(campaign.id)
    end

    it "clears campaign when blank" do
      campaign = create(:campaign, client: api_client)
      ad = create(:ad, client: api_client, campaign: campaign)
      patch "/api/clients/#{api_client.id}/ads/#{ad.id}",
            params: { ad: { campaign_id: "" } }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["campaign_id"]).to be_nil
    end
  end
end
