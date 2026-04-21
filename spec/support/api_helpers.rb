# Shared helpers for API request specs.
#
# Provides a standard authenticated context with:
#   - user, account, account_user, client
#   - Devise sign_in via IntegrationHelpers
#
# Usage:
#   RSpec.describe "Api::Foos", type: :request do
#     include_context "api authenticated user"
#     ...
#   end

RSpec.shared_context "api authenticated user" do
  let(:account) { create(:account) }
  let(:user) { create(:user) }
  let(:account_user) { create(:account_user, account: account, user: user, is_owner: true) }
  let(:client) { create(:client, account: account, hidden: true) }

  before do
    account_user # ensure created
    client       # ensure created
    sign_in user
  end
end

RSpec.shared_context "api agency user" do
  let(:account) { create(:account, is_agency: true) }
  let(:user) { create(:user) }
  let(:account_user) { create(:account_user, account: account, user: user, is_owner: true) }
  let(:client) { create(:client, account: account) }

  before do
    account_user
    client
    sign_in user
  end
end

RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
end
