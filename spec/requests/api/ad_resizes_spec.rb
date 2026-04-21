require 'rails_helper'

RSpec.describe "Api::AdResizes", type: :request do
  include_context "api authenticated user"

  let(:ad) { create(:ad, client: client, width: 1080, height: 1080) }
  let(:resize) { create(:ad_resize, ad: ad, width: 728, height: 90, aspect_ratio: "728:90") }

  describe "PATCH /api/clients/:client_id/ads/:ad_id/ad_resizes/:id" do
    it "updates layer_overrides" do
      overrides = { "layer1" => { "font_size" => 18 } }
      patch "/api/clients/#{client.id}/ads/#{ad.id}/ad_resizes/#{resize.id}",
            params: { layer_overrides: overrides }

      expect(response).to have_http_status(:ok)
      resize.reload
      # Params come through as strings
      expect(resize.layer_overrides["layer1"]["font_size"]).to be_present
    end
  end

  describe "POST /api/clients/:client_id/ads/:ad_id/ad_resizes/:id/rebuild" do
    it "rebuilds the resize" do
      allow(AdResizeService).to receive(:rebuild).and_return(resize)

      post "/api/clients/#{client.id}/ads/#{ad.id}/ad_resizes/#{resize.id}/rebuild"
      expect(response).to have_http_status(:ok)
      expect(AdResizeService).to have_received(:rebuild).with(resize)
    end

    it "returns 422 on service error" do
      allow(AdResizeService).to receive(:rebuild).and_raise(AdResizeService::Error, "Cannot rebuild")

      post "/api/clients/#{client.id}/ads/#{ad.id}/ad_resizes/#{resize.id}/rebuild"
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
