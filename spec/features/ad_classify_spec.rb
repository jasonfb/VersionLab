require 'rails_helper'

describe 'Ad element classification flow', type: :feature, js: true do
  let(:user) { create(:user, email: 'owner@example.com', password: 'password') }
  let(:account) { create(:account, name: 'Test Agency', is_agency: true) }
  let!(:account_user) { AccountUser.create!(user: user, account: account, is_owner: true) }
  let!(:client) { account.clients.create!(name: 'Acme Corp', hidden: false) }

  let!(:ad) do
    ad = client.ads.create!(
      name: 'Classify Test Ad',
      state: 'setup',
      parsed_layers: [
        { 'id' => 'layer_0', 'type' => 'text', 'content' => 'Big Sale', 'font_size' => '48', 'x' => '100', 'y' => '100' },
        { 'id' => 'layer_1', 'type' => 'text', 'content' => 'Up to 50% off everything', 'font_size' => '24', 'x' => '100', 'y' => '250' },
        { 'id' => 'layer_2', 'type' => 'text', 'content' => 'Shop Now', 'font_size' => '20', 'x' => '400', 'y' => '800' }
      ],
      classified_layers: [
        { 'id' => 'layer_0', 'type' => 'text', 'content' => 'Big Sale', 'font_size' => '48', 'x' => '100', 'y' => '100', 'role' => 'headline', 'confidence' => 0.85 },
        { 'id' => 'layer_1', 'type' => 'text', 'content' => 'Up to 50% off everything', 'font_size' => '24', 'x' => '100', 'y' => '250', 'role' => 'subhead', 'confidence' => 0.7 },
        { 'id' => 'layer_2', 'type' => 'text', 'content' => 'Shop Now', 'font_size' => '20', 'x' => '400', 'y' => '800', 'role' => 'cta', 'confidence' => 0.9 }
      ],
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

  before { sign_in user }

  describe 'happy path: classify → resize → style → version' do
    it 'starts on the Classify step and shows classified layers' do
      visit "/app/clients/#{client.id}/ads/#{ad.id}"

      # Should see the Classify step indicator as active
      expect(page).to have_content('Classify', wait: 10)
      expect(page).to have_content('ELEMENT ROLES')

      # Should display all three text layers with their auto-classified roles
      expect(page).to have_content('Big Sale')
      expect(page).to have_content('Up to 50% off everything')
      expect(page).to have_content('Shop Now')

      # Should show role dropdowns with pre-selected values
      role_selects = all('select.form-select-sm')
      expect(role_selects.length).to be >= 3

      # The first select (headline) should have 'headline' selected
      expect(role_selects[0].value).to eq('headline')
      # CTA should be detected
      expect(role_selects[2].value).to eq('cta')
    end

    it 'allows changing a role and confirming classifications' do
      visit "/app/clients/#{client.id}/ads/#{ad.id}"
      expect(page).to have_content('ELEMENT ROLES', wait: 10)

      # Change the subhead to body
      role_selects = all('select.form-select-sm')
      role_selects[1].select('Body')

      # Click confirm
      click_on 'Confirm & Continue'

      # Should advance to the Resize step
      expect(page).to have_content('Back to Classify', wait: 10)

      # Verify the classifications were persisted
      ad.reload
      expect(ad.classifications_confirmed).to be true
      layer_1 = ad.classified_layers.find { |l| l['id'] == 'layer_1' }
      expect(layer_1['role']).to eq('body')
    end

    it 'navigates through all four steps' do
      # Start with confirmed classifications to test full flow
      ad.update!(classifications_confirmed: true)

      visit "/app/clients/#{client.id}/ads/#{ad.id}"

      # Should start on Step 2 (Resize) since classifications are confirmed
      expect(page).to have_content('Back to Classify', wait: 10)

      # Can go back to Classify
      click_on 'Back to Classify'
      expect(page).to have_content('ELEMENT ROLES', wait: 10)

      # Re-confirm and move forward
      click_on 'Confirm & Continue'
      expect(page).to have_content('Back to Classify', wait: 10)

      # Skip resizing to go to Style
      click_on 'Skip Resizing'

      # Should be on Style step
      expect(page).to have_content('Background', wait: 10)
      expect(page).to have_content('Back to Resize')

      # Continue to Versioning
      click_on 'Continue to Versioning'

      # Should be on Version step
      expect(page).to have_content('Back to Style', wait: 10)
      expect(page).to have_content('AD NAME')
    end
  end

  describe 'resuming an ad with confirmed classifications' do
    before { ad.update!(classifications_confirmed: true) }

    it 'skips Classify and starts on Resize' do
      visit "/app/clients/#{client.id}/ads/#{ad.id}"
      expect(page).to have_content('Back to Classify', wait: 10)
    end
  end
end
