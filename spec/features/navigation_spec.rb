require 'rails_helper'

describe 'App navigation', type: :feature, js: true do
  let(:user) { create(:user, email: 'owner@example.com', password: 'password') }
  let(:account) { create(:account, name: 'Test Org') }
  let!(:account_user) { AccountUser.create!(user: user, account: account, is_owner: true) }
  let!(:client) { account.clients.create!(name: account.name, hidden: true) }

  before { sign_in user }

  describe 'sidebar navigation' do
    it 'navigates to Templates via sidebar' do
      visit '/app'
      find('[data-tooltip="Templates"]', wait: 10).click
      expect(page).to have_content('Templates', wait: 10)
    end

    it 'navigates to Audiences via sidebar' do
      visit '/app'
      find('[data-tooltip="Audiences"]', wait: 10).click
      expect(page).to have_content('Audiences', wait: 10)
    end

    it 'navigates to Emails via sidebar' do
      visit '/app'
      find('[data-tooltip="Emails"]', wait: 10).click
      expect(page).to have_content('Emails', wait: 10)
    end

    it 'navigates to Ads via sidebar' do
      visit '/app'
      find('[data-tooltip="Ads"]', wait: 10).click
      expect(page).to have_content('Ads', wait: 10)
    end

    it 'navigates to Assets via sidebar' do
      visit '/app'
      find('[data-tooltip="Assets"]', wait: 10).click
      expect(page).to have_content('Assets', wait: 10)
    end

    it 'navigates to Settings via sidebar' do
      visit '/app'
      find('[data-tooltip="Settings"]', wait: 10).click
      expect(page).to have_content('Settings', wait: 10)
    end
  end

  describe 'agency navigation' do
    let(:account) { create(:account, name: 'Agency Org', is_agency: true) }
    let!(:visible_client) { account.clients.create!(name: 'Client A', hidden: false) }

    it 'shows Clients in sidebar for agency accounts' do
      visit '/app'
      expect(page).to have_css('[data-tooltip="Clients"]', wait: 10)

      find('[data-tooltip="Clients"]').click
      expect(page).to have_content('Clients', wait: 10)
      expect(page).to have_content('Client A', wait: 10)
    end
  end

  describe 'React SPA catch-all' do
    it 'serves the React app for /app subpaths' do
      visit '/app/templates'
      expect(page).to have_content('Templates', wait: 10)
    end

    it 'serves the React app for deep routes' do
      visit '/app/audiences'
      expect(page).to have_content('Audiences', wait: 10)
    end
  end
end
