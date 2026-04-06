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
class AdVersion < ApplicationRecord
  belongs_to :ad
  belongs_to :ad_resize, optional: true
  belongs_to :audience
  belongs_to :ai_service
  belongs_to :ai_model

  has_one_attached :rendered_image

  enum :state, { generating: "generating", active: "active", rejected: "rejected" }

  validates :version_number, presence: true

  scope :active, -> { where(state: "active") }
end
