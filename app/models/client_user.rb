# == Schema Information
#
# Table name: client_users
# Database name: primary
#
#  id         :uuid             not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  client_id  :uuid             not null
#  user_id    :uuid             not null
#
# Indexes
#
#  index_client_users_on_client_id_and_user_id  (client_id,user_id) UNIQUE
#
class ClientUser < ApplicationRecord
  belongs_to :client
  belongs_to :user
end
