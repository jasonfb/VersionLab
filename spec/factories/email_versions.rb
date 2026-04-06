# == Schema Information
#
# Table name: email_versions
# Database name: primary
#
#  id                :uuid             not null, primary key
#  rejection_comment :text
#  state             :enum             default("generating"), not null
#  version_number    :integer          default(1), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  ai_model_id       :uuid             not null
#  ai_service_id     :uuid             not null
#  audience_id       :uuid             not null
#  email_id          :uuid             not null
#
# Indexes
#
#  idx_merge_versions_on_merge_and_audience  (email_id,audience_id)
#  idx_merge_versions_unique                 (email_id,audience_id,version_number) UNIQUE
#
FactoryBot.define do
  factory :email_version do
    email
    audience
    ai_service
    ai_model
    state { "generating" }
    sequence(:version_number) { |n| n }
  end
end
