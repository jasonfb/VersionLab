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
class EmailAudience < ApplicationRecord
  belongs_to :email
  belongs_to :audience
end
