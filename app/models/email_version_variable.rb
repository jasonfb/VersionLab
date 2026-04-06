# == Schema Information
#
# Table name: email_version_variables
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  value                :text             not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  email_version_id     :uuid             not null
#  template_variable_id :uuid             not null
#
# Indexes
#
#  idx_merge_version_variables_unique  (email_version_id,template_variable_id) UNIQUE
#
class EmailVersionVariable < ApplicationRecord
  belongs_to :email_version
  belongs_to :template_variable

  validates :value, presence: true
  validates :template_variable_id, uniqueness: { scope: :email_version_id }
end
