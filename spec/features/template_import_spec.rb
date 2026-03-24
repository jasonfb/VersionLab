require 'rails_helper'

describe 'Email template import', type: :feature, js: true do
  let(:user) { create(:user, email: 'tester@example.com', password: 'password') }
  let(:account) { create(:account, name: 'Test Org') }
  let!(:account_user) { AccountUser.create!(user: user, account: account, is_owner: true) }
  let!(:client) { account.clients.create!(name: account.name, hidden: true) }

  before do
    ActiveJob::Base.queue_adapter = :inline
    sign_in user
  end

  after do
    ActiveJob::Base.queue_adapter = :test
  end

  def navigate_to_new_template
    visit '/app'
    expect(page).to have_css('[data-tooltip="Templates"]', wait: 10)
    find('[data-tooltip="Templates"]').click
    expect(page).to have_content('Email Templates', wait: 10)
    click_link 'New Template'
    expect(page).to have_content('New Email Template', wait: 10)
  end

  describe 'external linked images' do
    around do |example|
      VCR.turned_off do
        WebMock.allow_net_connect!

        png = Base64.decode64(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=='
        )
        WebMock.stub_request(:get, /stripocdn\.email/).to_return(
          status: 200, body: png, headers: { 'Content-Type' => 'image/png' }
        )
        WebMock.stub_request(:get, /eep\.io/).to_return(
          status: 200, body: png, headers: { 'Content-Type' => 'image/png' }
        )

        example.run

        WebMock.reset!
      end
    end

    it 'uploads an HTML file and processes external images into assets' do
      navigate_to_new_template

      find('input.form-control[type="text"]').set('AF Example Template')
      find('input[value="external"]').click
      find('input[type="file"]').set(file_fixture('af-example.html').to_s)
      click_button 'Import Template'

      # Wait for the API call to complete and the import to process
      expect(page).to have_content('Queued').or(have_content('Importing')).or(have_content('Import complete'))

      template = EmailTemplate.find_by(name: 'AF Example Template')
      expect(template).to be_present
      expect(template.client).to eq(client)

      import = template.template_import
      expect(import).to be_present
      expect(import.import_type).to eq('external')
      expect(import.state).to eq('completed')

      # External images were downloaded and stored as assets
      expect(template.raw_source_html).to include('{{vl-asset:')
      expect(template.raw_source_html).not_to match(/src=["']https?:\/\//)
      expect(Asset.where(client: client).count).to be > 0
    end
  end

  describe 'bundled zip file' do
    it 'uploads a ZIP and processes bundled images into assets' do
      navigate_to_new_template

      find('input.form-control[type="text"]').set('AF Feb Cold Template')
      find('input[value="bundled"]').click
      find('input[type="file"]').set(file_fixture('br-test-AF_Feb_Cold_v01.zip').to_s)
      click_button 'Import Template'

      # Wait for the upload to finish — the button disappears when the import starts
      expect(page).not_to have_button('Import Template', wait: 15)

      template = EmailTemplate.find_by(name: 'AF Feb Cold Template')
      expect(template).to be_present
      expect(template.client).to eq(client)

      import = template.template_import
      expect(import).to be_present
      expect(import.import_type).to eq('bundled')
      expect(import.state).to eq('completed')

      # Bundled images were extracted and stored as assets
      expect(template.raw_source_html).to include('{{vl-asset:')
      expect(template.raw_source_html).not_to match(/src=["']images\//)

      # The ZIP has 20 image files in images/
      expect(Asset.where(client: client).count).to eq(20)
    end
  end
end
