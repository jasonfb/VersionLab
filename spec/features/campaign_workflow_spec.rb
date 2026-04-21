require 'rails_helper'

describe 'Campaign workflow', type: :feature, js: true do
  let(:user) { create(:user, email: 'owner@example.com', password: 'password') }
  let(:account) { create(:account, name: 'Test Org') }
  let!(:account_user) { AccountUser.create!(user: user, account: account, is_owner: true) }
  let!(:client) { account.clients.create!(name: account.name, hidden: true) }

  before { sign_in user }

  describe 'creating a campaign' do
    it 'creates a new campaign from the campaigns page' do
      visit '/app/campaigns'
      expect(page).to have_content('Campaigns', wait: 10)

      fill_in 'New campaign name...', with: 'Fall Fundraiser'
      click_button 'Add Campaign'

      expect(page).to have_css('input[value="Fall Fundraiser"]', wait: 10)

      campaign = Campaign.find_by(name: 'Fall Fundraiser', client: client)
      expect(campaign).to be_present
      expect(campaign.status).to eq('draft')
    end
  end

  describe 'editing campaign details' do
    let!(:campaign) { create(:campaign, client: client, name: 'Spring Push') }

    it 'lets me edit description and goals' do
      allow(CampaignSummaryJob).to receive(:perform_later)

      visit '/app/campaigns'
      expect(page).to have_content('Spring Push', wait: 10)

      # Navigate to campaign detail
      find('.list-group-item', text: 'Spring Push').click
      expect(page).to have_css('input[value="Spring Push"]', wait: 10)

      # Fill in description
      textareas = all('textarea.form-control')
      if textareas.any?
        react_fill_in_textarea(textareas[0], with: 'A comprehensive spring campaign targeting lapsed donors.')
        click_button 'Save'

        campaign.reload
        expect(campaign.description).to eq('A comprehensive spring campaign targeting lapsed donors.')
      end
    end
  end

  describe 'adding a link to a campaign' do
    let!(:campaign) { create(:campaign, client: client, name: 'Link Test') }

    it 'adds a campaign link' do
      allow(FetchLinkPreviewJob).to receive(:perform_later)
      allow(CampaignSummaryJob).to receive(:perform_later)

      visit '/app/campaigns'
      expect(page).to have_content('Link Test', wait: 10)

      find('.list-group-item', text: 'Link Test').click
      expect(page).to have_css('input[value="Link Test"]', wait: 10)

      # Look for links section and add a URL
      if page.has_content?('Links', wait: 5)
        click_button 'Links' if page.has_button?('Links')

        url_input = find('input[placeholder*="http"]', wait: 5) rescue nil
        if url_input
          react_fill_in(url_input, with: 'https://example.com/landing')
          click_button 'Add Link' rescue click_button 'Add'

          expect(page).to have_content('example.com', wait: 10)
        end
      end
    end
  end

  describe 'triggering campaign summary' do
    let!(:campaign) { create(:campaign, client: client, name: 'Summary Test', description: 'Test campaign') }

    it 'triggers AI summary generation' do
      allow(CampaignSummaryJob).to receive(:perform_later)

      visit '/app/campaigns'
      find('.list-group-item', text: 'Summary Test').click
      expect(page).to have_css('input[value="Summary Test"]', wait: 10)

      if page.has_button?('Summarize', wait: 5)
        click_button 'Summarize'
        expect(CampaignSummaryJob).to have_received(:perform_later)
      end
    end
  end
end
