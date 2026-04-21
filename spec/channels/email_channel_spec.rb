require 'rails_helper'

RSpec.describe EmailChannel, type: :channel do
  let(:account) { create(:account) }
  let(:user) { create(:user) }
  let!(:account_user) { create(:account_user, account: account, user: user) }
  let(:client) { create(:client, account: account) }
  let(:template) { create(:email_template, client: client) }
  let(:email) { create(:email, client: client, email_template: template) }

  before do
    stub_connection(current_user: user)
  end

  describe "#subscribed" do
    it "streams from the email channel" do
      subscribe(email_id: email.id)
      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("email:#{email.id}")
    end

    it "rejects when email not found" do
      subscribe(email_id: SecureRandom.uuid)
      expect(subscription).to be_rejected
    end

    it "rejects when email belongs to different account" do
      other_account = create(:account)
      other_client = create(:client, account: other_account)
      other_template = create(:email_template, client: other_client)
      other_email = create(:email, client: other_client, email_template: other_template)

      subscribe(email_id: other_email.id)
      expect(subscription).to be_rejected
    end
  end
end
