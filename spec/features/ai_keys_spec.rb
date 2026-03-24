require 'rails_helper'

describe 'AI service key management', type: :feature, js: true do
  let(:user) { create(:user, email: 'owner@example.com', password: 'password') }
  let(:account) { create(:account, name: 'Test Org') }
  let!(:account_user) { AccountUser.create!(user: user, account: account, is_owner: true) }
  let!(:client) { account.clients.create!(name: account.name, hidden: true) }

  # Ensure at least one AI service exists (seeded via data migration)
  let!(:ai_service) do
    AiService.first || AiService.create!(name: 'OpenAI', slug: 'openai')
  end

  before do
    sign_in user
  end

  def navigate_to_ai_keys
    visit '/app/settings'
    expect(page).to have_content('Settings', wait: 10)
    click_button 'AI Keys'
    expect(page).to have_content('Add API Key', wait: 10)
  end

  describe 'adding an AI service key' do
    it 'lets me add and see a new API key' do
      navigate_to_ai_keys

      # Fill in the form
      find('select.form-select').select(ai_service.name)
      find('input[type="password"]').set('sk-test-1234567890abcdef')
      find('input[type="text"]').set('Production')
      click_button 'Save'

      # Key should appear in the list with masked value
      expect(page).to have_content(ai_service.name, wait: 10)
      expect(page).to have_content('sk-t...cdef')
      expect(page).to have_content('Production')

      # Verify in database
      key = AiKey.find_by(account: account, ai_service: ai_service)
      expect(key).to be_present
      expect(key.api_key).to eq('sk-test-1234567890abcdef')
      expect(key.label).to eq('Production')
    end
  end

  describe 'deleting an AI service key' do
    let!(:ai_key) do
      AiKey.create!(account: account, ai_service: ai_service, api_key: 'sk-delete-me-12345678', label: 'Old Key')
    end

    it 'lets me delete an existing API key' do
      navigate_to_ai_keys

      expect(page).to have_content(ai_service.name, wait: 10)
      expect(page).to have_content('Old Key')

      # Click the delete button and accept confirmation
      accept_confirm('Delete this API key?') do
        find('button[title="Delete"]').click
      end

      # Key should be removed from the list
      expect(page).not_to have_content('Old Key', wait: 10)

      # Verify in database
      expect(AiKey.find_by(id: ai_key.id)).to be_nil
    end
  end
end
