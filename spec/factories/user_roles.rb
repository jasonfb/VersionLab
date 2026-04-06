# == Schema Information
#
# Table name: user_roles
# Database name: primary
#
#  id         :uuid             not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  role_id    :uuid
#  user_id    :uuid
#
FactoryBot.define do
  factory :user_role do
    user
    role
  end
end
