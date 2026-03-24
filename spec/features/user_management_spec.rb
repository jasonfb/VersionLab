require 'rails_helper'

describe 'User management', type: :feature, js: true do
  let(:user) { create(:user, email: 'owner@example.com', password: 'password') }
  let(:account) { create(:account, name: 'Test Agency', is_agency: true) }
  let!(:account_user) { AccountUser.create!(user: user, account: account, is_owner: true) }
  let!(:client) { account.clients.create!(name: 'Acme Corp', hidden: false) }

  before do
    sign_in user
  end

  describe 'adding a user as an agency owner' do
    it 'lets me add a user by email in Settings' do
      visit '/app/settings'
      expect(page).to have_content('Settings', wait: 10)

      # Click the Users tab
      click_button 'Users'
      expect(page).to have_content('Add User', wait: 10)

      # Add a new user by email
      fill_in 'Email address', with: 'newmember@example.com'
      click_button 'Add User'

      # Should show the new user in the list
      expect(page).to have_content('newmember@example.com', wait: 10)

      # Verify the user was created in the database
      new_user = User.find_by(email: 'newmember@example.com')
      expect(new_user).to be_present

      account_membership = AccountUser.find_by(user: new_user, account: account)
      expect(account_membership).to be_present
    end
  end

  describe 'assigning a user to a client' do
    let!(:member) { create(:user, email: 'member@example.com', password: 'password') }
    let!(:member_account_user) { AccountUser.create!(user: member, account: account, is_owner: false) }

    it 'lets me assign a team member to a client' do
      visit '/app/clients'
      expect(page).to have_content('Acme Corp', wait: 10)

      # Click on the client
      click_link 'Acme Corp'
      expect(page).to have_content('Acme Corp', wait: 10)

      # Click the Users tab
      click_button 'Users'
      expect(page).to have_content('member@example.com', wait: 10)

      # The member should have an "Assign" button
      member_row = find('.list-group-item', text: 'member@example.com')
      within(member_row) do
        click_button 'Assign'
        expect(page).to have_content('Assigned', wait: 10)
      end

      # Verify the assignment in the database
      client_user = ClientUser.find_by(user: member, client: client)
      expect(client_user).to be_present
    end
  end
end
