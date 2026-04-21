require 'rails_helper'

describe 'Login', type: :feature, js: true do
  let!(:user) { create(:user, email: 'jason@heliosdev.shop', password: 'password') }
  let!(:account) { create(:account, name: 'Test Org') }
  let!(:account_user) { AccountUser.create!(user: user, account: account, is_owner: true) }
  let!(:client) { account.clients.create!(name: account.name, hidden: true) }

  describe 'with valid credentials' do
    it 'logs in successfully' do
      visit '/users/sign_in'
      fill_in 'Email', with: 'jason@heliosdev.shop'
      fill_in 'Password', with: 'password'
      click_button 'Log in'

      # Devise redirects to root after login; user is authenticated
      expect(page).not_to have_button('Log in', wait: 5)
    end
  end

  describe 'with invalid credentials' do
    it 'does not log in and keeps the login form visible' do
      visit '/users/sign_in'
      fill_in 'Email', with: 'jason@heliosdev.shop'
      fill_in 'Password', with: 'wrongpassword'
      click_button 'Log in'

      # Should remain on login page, not redirect
      expect(page).to have_button('Log in', wait: 5)
      expect(page).to have_field('Email')
    end

    it 'does not log in with nonexistent email' do
      visit '/users/sign_in'
      fill_in 'Email', with: 'nonexistent@example.com'
      fill_in 'Password', with: 'password'
      click_button 'Log in'

      expect(page).to have_button('Log in', wait: 5)
    end
  end

  describe 'unauthenticated access' do
    it 'redirects /app to login when not signed in' do
      visit '/app'
      expect(page).to have_current_path('/users/sign_in', wait: 5)
    end
  end
end
