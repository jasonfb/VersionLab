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
class UserRole < ApplicationRecord
  belongs_to :user
  belongs_to :role

end
