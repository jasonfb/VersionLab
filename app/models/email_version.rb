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
class EmailVersion < ApplicationRecord
  belongs_to :email
  belongs_to :audience
  belongs_to :ai_service
  belongs_to :ai_model
  has_many :email_version_variables, dependent: :destroy

  enum :state, { generating: "generating", active: "active", rejected: "rejected" }

  validates :version_number, presence: true
end
