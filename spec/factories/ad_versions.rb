# == Schema Information
#
# Table name: ad_versions
# Database name: primary
#
#  id                :uuid             not null, primary key
#  generated_layers  :jsonb
#  rejection_comment :text
#  state             :enum             default("generating"), not null
#  version_number    :integer          default(1), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  ad_id             :uuid             not null
#  ad_resize_id      :uuid
#  ai_model_id       :uuid             not null
#  ai_service_id     :uuid             not null
#  audience_id       :uuid             not null
#
# Indexes
#
#  idx_ad_versions_on_ad_resize_audience       (ad_id,ad_resize_id,audience_id)
#  idx_ad_versions_unique_per_resize_audience  (ad_id,ad_resize_id,audience_id,version_number) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ad_id => ads.id)
#  fk_rails_...  (ad_resize_id => ad_resizes.id)
#  fk_rails_...  (audience_id => audiences.id)
#
FactoryBot.define do
  factory :ad_version do
    ad
    audience
    ai_service
    ai_model
    state { "generating" }
    sequence(:version_number) { |n| n }
  end
end
