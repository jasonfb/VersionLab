RSpec.shared_context "admin authenticated user" do
  let(:admin_user) do
    user = create(:user)
    admin_role = Role.find_or_create_by!(name: "admin")
    user.roles << admin_role
    user
  end

  before { sign_in admin_user }
end

RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
end
