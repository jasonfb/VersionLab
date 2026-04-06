require 'rails_helper'

describe 'Ad upload and versioning', type: :feature, js: true do
  let(:user) { create(:user, email: 'owner@example.com', password: 'password') }
  let(:account) { create(:account, name: 'Test Agency', is_agency: true) }
  let!(:account_user) { AccountUser.create!(user: user, account: account, is_owner: true) }
  let!(:client) { account.clients.create!(name: 'Acme Corp', hidden: false) }

  before do
    sign_in user
  end

  describe 'uploading a PDF ad' do
    it 'uploads a PDF, parses it, and shows the ad editor with layers' do
      visit '/app/ads'
      expect(page).to have_content('Ads', wait: 10)

      # The file input is hidden; attach directly
      find('input[type="file"]', visible: false).set(
        file_fixture('1_SolidBkg_StaticType.pdf').to_s
      )

      # Should navigate to the ad edit page after upload
      expect(page).to have_content('1_SolidBkg_StaticType', wait: 15)

      # Verify the ad was created and parsed
      ad = Ad.find_by(client: client)
      expect(ad).to be_present
      expect(ad.file).to be_attached
      expect(ad.state).to eq('setup')

      # The PDF should have been parsed for dimensions
      expect(ad.width).to be_present
      expect(ad.height).to be_present
    end
  end

  describe 'generating ad versions' do
    let!(:campaign) { Campaign.create!(name: 'Spring 2026', client: client) }
    let!(:audience) { Audience.create!(name: 'Cold Lapsed', client: client) }
    let!(:ai_service) { AiService.first || AiService.create!(name: 'OpenAI', slug: 'openai') }
    let!(:ai_model) { ai_service.ai_models.first || ai_service.ai_models.create!(name: 'GPT-4o', api_identifier: 'gpt-4o', for_text: true, for_image: false) }
    let!(:ai_key) { AiKey.find_by(ai_service: ai_service) || AiKey.create!(ai_service: ai_service, api_key: 'sk-test-key-1234567890') }

    # Create an ad with a pre-parsed PDF so we can test the generation flow
    let!(:ad) do
      ad = client.ads.create!(
        name: 'Test Ad',
        state: 'setup',
        parsed_layers: [
          { 'id' => 'layer_0', 'type' => 'text', 'content' => 'Headline Text', 'font_size' => '24' },
          { 'id' => 'layer_1', 'type' => 'text', 'content' => 'Body copy here', 'font_size' => '14' }
        ],
        classified_layers: [
          { 'id' => 'layer_0', 'type' => 'text', 'content' => 'Headline Text', 'font_size' => '24', 'role' => 'headline', 'confidence' => 0.85 },
          { 'id' => 'layer_1', 'type' => 'text', 'content' => 'Body copy here', 'font_size' => '14', 'role' => 'body', 'confidence' => 0.7 }
        ],
        classifications_confirmed: true,
        width: 1080,
        height: 1080,
        aspect_ratio: '1:1'
      )
      ad.file.attach(
        io: File.open(file_fixture('1_SolidBkg_StaticType.pdf')),
        filename: 'test.pdf',
        content_type: 'application/pdf'
      )
      ad
    end

    before do
      # Stub AdMergeService to avoid real AI API calls
      allow_any_instance_of(AdMergeService).to receive(:call).and_wrap_original do |_method, *_args|
        # Create a mock ad version for each audience
        ad.audiences.each do |aud|
          ad.ad_versions.create!(
            audience: aud,
            state: :active,
            generated_layers: [
              { 'id' => 'layer_0', 'content' => 'AI Generated Headline' },
              { 'id' => 'layer_1', 'content' => 'AI generated body copy' }
            ]
          )
        end
      end

      ActiveJob::Base.queue_adapter = :inline
    end

    after do
      ActiveJob::Base.queue_adapter = :test
    end

    it 'shows the ad editor with parsed layers and allows configuration' do
      visit "/app/clients/#{client.id}/ads/#{ad.id}"
      expect(page).to have_content('Test Ad', wait: 10)

      # Step 2 (Resize) is shown since classifications are confirmed — skip to Step 3 (Style)
      click_on 'Skip Resizing'
      expect(page).to have_content('Back to Resize', wait: 5)

      # Continue to Step 4 (Version)
      click_on 'Continue to Versioning'

      # The version step should show detected text layers
      expect(page).to have_content('Headline Text', wait: 5)
      expect(page).to have_content('Body copy here')

      # Select "Version Ads" mode to reveal campaign/audience/AI options
      choose('Version Ads')

      # Campaign, audience, and AI service options should now appear
      expect(page).to have_content('Cold Lapsed', wait: 5)
      expect(page).to have_content(ai_service.name)
    end
  end
end
