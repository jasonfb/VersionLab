require 'rails_helper'

describe 'Audience management', type: :feature, js: true do
  let(:user) { create(:user, email: 'tester@example.com', password: 'password') }
  let(:account) { create(:account, name: 'Test Org') }
  let!(:account_user) { AccountUser.create!(user: user, account: account, is_owner: true) }
  let!(:client) { account.clients.create!(name: account.name, hidden: true) }

  before do
    sign_in user
  end

  def navigate_to_audiences
    visit '/app/audiences'
    expect(page).to have_content('Audiences', wait: 10)
  end

  describe 'creating an audience' do
    it 'lets me create a new audience with a name' do
      navigate_to_audiences

      click_button 'New Audience'
      fill_in 'Audience name', with: 'Midlevel Donors'
      click_button 'Create'

      # Should navigate to the detail page
      expect(page).to have_content('Midlevel Donors', wait: 10)
      expect(page).to have_text(/audience intelligence/i)

      audience = Audience.find_by(name: 'Midlevel Donors')
      expect(audience).to be_present
      expect(audience.client).to eq(client)
    end
  end

  describe 'editing an audience' do
    let!(:audience) { Audience.create!(name: 'Cold Lapsed', client: client) }

    it 'lets me edit and save all fields on the audience screen' do
      navigate_to_audiences

      # Click the Edit button on the row
      find('button[title="Edit"]').click
      expect(page).to have_content('Back to Audiences', wait: 10)

      # Edit basic fields — clear first, then set via native setter + React events
      name_input = find('input.form-control[type="text"]')
      name_input.native.clear
      react_fill_in(name_input, with: 'Cold Lapsed Updated')

      textareas = all('textarea.form-control')
      # textareas[0] = details, [1] = Executive Summary, [2] = Demographics...
      react_fill_in_textarea(textareas[0], with: 'Donors who have lapsed 12+ months')
      react_fill_in_textarea(textareas[1], with: 'High-value donors who stopped giving over a year ago.')
      react_fill_in_textarea(textareas[2], with: 'Age 45-65, income $75k+, suburban households.')

      click_button 'Save'

      # Wait for the async save to complete
      expect(page).not_to have_button('Saving…', wait: 5)

      # Verify the data was persisted
      audience.reload
      expect(audience.name).to eq('Cold Lapsed Updated')
      expect(audience.details).to eq('Donors who have lapsed 12+ months')
      expect(audience.executive_summary).to eq('High-value donors who stopped giving over a year ago.')
      expect(audience.demographics_and_financial_capacity).to eq('Age 45-65, income $75k+, suburban households.')
    end
  end
end
