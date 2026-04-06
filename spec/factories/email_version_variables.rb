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
FactoryBot.define do
  factory :email_version_variable do
    email_version
    template_variable
    value { "Generated value" }
  end
end
