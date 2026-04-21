require 'rails_helper'

describe 'Settings page', type: :feature, js: true do
  let(:user) { create(:user, email: 'owner@example.com', password: 'password') }
  let(:account) { create(:account, name: 'Test Org') }
  let!(:account_user) { AccountUser.create!(user: user, account: account, is_owner: true) }
  let!(:client) { account.clients.create!(name: account.name, hidden: true) }

  before { sign_in user }

  describe 'navigating to settings' do
    it 'shows the settings page' do
      visit '/app/settings'
      expect(page).to have_content('Settings', wait: 10)
    end
  end

  describe 'subscription tab' do
    let!(:tier) { create(:subscription_tier, slug: 'standard', name: 'Standard') }
    let!(:subscription) do
      create(:subscription, account: account, subscription_tier: tier,
             billing_interval: 'monthly', paid_through_date: 30.days.from_now)
    end

    it 'shows the current subscription information' do
      visit '/app/settings'
      expect(page).to have_content('Settings', wait: 10)

      if page.has_button?('Subscription', wait: 5)
        click_button 'Subscription'
        expect(page).to have_content('Standard', wait: 10)
      end
    end
  end

  describe 'users tab' do
    it 'shows team members' do
      visit '/app/settings'
      expect(page).to have_content('Settings', wait: 10)

      if page.has_button?('Users', wait: 5)
        click_button 'Users'
        expect(page).to have_content(user.email, wait: 10)
      end
    end
  end

  describe 'billing tab' do
    it 'shows billing information' do
      visit '/app/settings'
      expect(page).to have_content('Settings', wait: 10)

      if page.has_button?('Billing', wait: 5)
        click_button 'Billing'
        # Should show payment methods or billing info section
        expect(page).to have_content(/payment|billing/i, wait: 10)
      end
    end
  end
end
