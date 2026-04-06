# == Schema Information
#
# Table name: campaign_documents
# Database name: primary
#
#  id           :uuid             not null, primary key
#  content_text :text
#  display_name :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  campaign_id  :uuid             not null
#
# Indexes
#
#  index_campaign_documents_on_campaign_id  (campaign_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#
class CampaignDocument < ApplicationRecord
  belongs_to :campaign
  has_one_attached :file

  validates :display_name, presence: true

  after_commit :trigger_summary, on: [ :create, :destroy ]

  private

  def trigger_summary
    CampaignSummaryJob.perform_later(campaign_id)
  end
end
