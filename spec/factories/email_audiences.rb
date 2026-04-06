# == Schema Information
#
# Table name: email_audiences
# Database name: primary
#
#  id          :uuid             not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  audience_id :uuid             not null
#  email_id    :uuid             not null
#
FactoryBot.define do
  factory :email_audience do
    email
    audience
  end
end
