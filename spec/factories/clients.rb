# == Schema Information
#
# Table name: clients
# Database name: primary
#
#  id         :uuid             not null, primary key
#  hidden     :boolean          default(FALSE), not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :uuid             not null
#
FactoryBot.define do
  factory :client do
    account
    name { "Test Client" }
  end
end
