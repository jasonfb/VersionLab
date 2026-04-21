require 'rails_helper'

describe 'Email merge workflow', type: :feature, js: true do
  let(:user) { create(:user, email: 'owner@example.com', password: 'password') }
  let(:account) { create(:account, name: 'Test Org') }
  let!(:account_user) { AccountUser.create!(user: user, account: account, is_owner: true) }
  let!(:client) { account.clients.create!(name: account.name, hidden: true) }
  let!(:template) do
    create(:email_template, client: client, name: 'Welcome Email',
           raw_source_html: '<html><body><h1>Hello</h1><p>Welcome!</p></body></html>')
  end
  let!(:audience) { create(:audience, client: client, name: 'Lapsed Donors') }

  let(:ai_service) { create(:ai_service, name: 'OpenAI', slug: 'openai') }
  let(:ai_model) { create(:ai_model, ai_service: ai_service, name: 'GPT-4o', api_identifier: 'gpt-4o') }
  let!(:ai_key) { create(:ai_key, ai_service: ai_service) }

  before { sign_in user }

  describe 'viewing the emails list' do
    it 'shows the Emails page' do
      visit '/app/emails'
      expect(page).to have_content('Emails', wait: 10)
    end
  end

  describe 'creating an email from a template' do
    it 'shows the template picker when clicking New Email' do
      visit '/app/emails'
      expect(page).to have_content('Emails', wait: 10)

      click_button 'New Email'
      expect(page).to have_content('Welcome Email', wait: 10)
    end
  end

  describe 'viewing email results' do
    let!(:email) do
      e = create(:email, client: client, email_template: template,
                 ai_service: ai_service, ai_model: ai_model, state: 'merged')
      e.audiences << audience
      e
    end
    let!(:version) do
      create(:email_version,
             email: email, audience: audience, state: 'active',
             version_number: 1, ai_service: ai_service, ai_model: ai_model)
    end

    it 'shows results page with audience versions' do
      visit "/app/clients/#{client.id}/emails/#{email.id}/results"
      expect(page).to have_content('Lapsed Donors', wait: 10)
    end
  end
end
