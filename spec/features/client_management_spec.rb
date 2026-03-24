require 'rails_helper'

describe 'Client management', type: :feature, js: true do
  let(:user) { create(:user, email: 'owner@example.com', password: 'password') }
  let(:account) { create(:account, name: 'Test Agency', is_agency: true) }
  let!(:account_user) { AccountUser.create!(user: user, account: account, is_owner: true) }

  before do
    sign_in user
  end

  describe 'creating a client' do
    it 'lets me create a new client from the Clients tab' do
      visit '/app/clients'
      expect(page).to have_content('Clients', wait: 10)

      fill_in 'New client name...', with: 'Acme Corp'
      click_button 'Create Client'

      expect(page).to have_content('Acme Corp', wait: 10)

      client = Client.find_by(name: 'Acme Corp', account: account)
      expect(client).to be_present
    end
  end

  describe 'editing a client' do
    let!(:client) { account.clients.create!(name: 'Old Name', hidden: false) }

    it 'lets me rename a client inline' do
      visit '/app/clients'
      expect(page).to have_content('Old Name', wait: 10)

      # Click the pencil edit button within the client row
      row = find('.list-group-item', text: 'Old Name')
      within(row) { find('button.btn-outline-secondary').click }

      # Wait for the inline edit input to appear (it has autoFocus)
      input = find('input.form-control-sm', wait: 5)

      # Clear via JS and type new name
      page.execute_script(<<~JS, input.native)
        var el = arguments[0];
        var nativeSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
        nativeSetter.call(el, '');
        el.dispatchEvent(new Event('input', { bubbles: true }));
      JS
      input.send_keys('New Name')

      click_button 'Save'

      expect(page).to have_content('New Name', wait: 10)

      client.reload
      expect(client.name).to eq('New Name')
    end
  end

  describe 'editing a brand profile' do
    let!(:client) { account.clients.create!(name: 'Acme Corp', hidden: false) }

    it 'lets me fill in and save brand profile fields' do
      visit '/app/clients'
      expect(page).to have_content('Acme Corp', wait: 10)

      click_link 'Acme Corp'
      expect(page).to have_content('Acme Corp', wait: 10)

      click_button 'Brand Profile'
      expect(page).to have_text(/identity/i, wait: 10)

      # Find inputs by placeholder since labels aren't for-linked
      org_name = find('input[placeholder="e.g. Acme Nonprofit"]')
      react_fill_in(org_name, with: 'Acme Corporation')

      domain = find('input[placeholder="e.g. acme.org"]')
      react_fill_in(domain, with: 'acme.com')

      mission = find('textarea', match: :first)
      react_fill_in_textarea(mission, with: 'Empowering businesses through innovation.')

      click_button 'Save'

      # Wait for save to complete
      expect(page).to have_button('Save', disabled: false, wait: 10)

      profile = BrandProfile.find_by(client: client)
      expect(profile).to be_present
      expect(profile.organization_name).to eq('Acme Corporation')
      expect(profile.primary_domain).to eq('acme.com')
      expect(profile.mission_statement).to eq('Empowering businesses through innovation.')
    end
  end

  describe 'creating a campaign within a client' do
    let!(:client) { account.clients.create!(name: 'Acme Corp', hidden: false) }

    it 'lets me create a campaign from the client detail page' do
      visit '/app/clients'
      expect(page).to have_content('Acme Corp', wait: 10)

      click_link 'Acme Corp'
      expect(page).to have_content('Campaigns', wait: 10)

      fill_in 'New campaign name...', with: 'Spring 2026'
      click_button 'Add Campaign'

      # Should navigate to the campaign detail page with the name in an input
      expect(page).to have_css('input[value="Spring 2026"]', wait: 10)

      campaign = Campaign.find_by(name: 'Spring 2026', client: client)
      expect(campaign).to be_present
      expect(campaign.status).to eq('draft')
    end
  end
end
