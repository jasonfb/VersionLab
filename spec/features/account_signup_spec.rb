require 'rails_helper'

describe 'Account signup', type: :feature do
  describe 'starting with an email address' do
    it 'presents an email field to get started' do
      visit '/start'
      expect(page).to have_field('email')
      expect(page).to have_button('Continue')
    end

    context 'when the email is already registered' do
      let!(:existing_user) { create(:user, email: 'taken@example.com') }

      it 'tells me to ask an account owner to add me' do
        visit '/start'
        fill_in 'email', with: 'taken@example.com'
        click_button 'Continue'

        expect(page).to have_content('already registered')
        expect(page).to have_content('ask your organization')
        expect(page).to have_link('Log in')
      end
    end

    context 'when the email is new' do
      it 'proceeds to the signup form' do
        visit '/start'
        fill_in 'email', with: 'brand_new@example.com'
        click_button 'Continue'

        expect(page).to have_current_path('/start/signup', ignore_query: true, wait: 5)
        expect(page).to have_field('Organization name')
        expect(page).to have_field('Password')
        expect(page).to have_field('Password confirmation')
      end
    end
  end

  describe 'completing signup' do
    it 'creates a new account where I am the owner' do
      visit '/start'
      fill_in 'email', with: 'newuser@example.com'
      click_button 'Continue'

      fill_in 'Organization name', with: 'My New Org'
      fill_in 'Password', with: 'securepassword'
      fill_in 'Password confirmation', with: 'securepassword'
      click_button 'Create Account'

      user = User.find_by(email: 'newuser@example.com')
      expect(user).to be_present

      account = user.accounts.first
      expect(account).to be_present
      expect(account.name).to eq('My New Org')

      account_user = AccountUser.find_by(user: user, account: account)
      expect(account_user.is_owner).to be true
    end

    it 'sets up a hidden default client for the new account' do
      visit '/start'
      fill_in 'email', with: 'another@example.com'
      click_button 'Continue'

      fill_in 'Organization name', with: 'Fresh Org'
      fill_in 'Password', with: 'securepassword'
      fill_in 'Password confirmation', with: 'securepassword'
      click_button 'Create Account'

      account = User.find_by(email: 'another@example.com').accounts.first
      expect(account.clients.count).to eq(1)
      expect(account.clients.first).to be_hidden
      expect(account.clients.first.name).to eq('Fresh Org')
    end

    it 'signs me in and redirects to the app' do
      visit '/start'
      fill_in 'email', with: 'signedin@example.com'
      click_button 'Continue'

      fill_in 'Organization name', with: 'SignedIn Org'
      fill_in 'Password', with: 'securepassword'
      fill_in 'Password confirmation', with: 'securepassword'
      click_button 'Create Account'

      expect(page).to have_current_path('/app')
    end
  end
end
