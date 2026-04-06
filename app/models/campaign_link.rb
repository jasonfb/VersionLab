# == Schema Information
#
# Table name: campaign_links
# Database name: primary
#
#  id               :uuid             not null, primary key
#  fetched_at       :datetime
#  image_url        :text
#  link_description :text
#  title            :string
#  url              :text             not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  campaign_id      :uuid             not null
#
# Indexes
#
#  index_campaign_links_on_campaign_id  (campaign_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#
class CampaignLink < ApplicationRecord
  belongs_to :campaign

  validates :url, presence: true

  after_commit :fetch_and_summarize, on: :create
  after_commit :trigger_summary, on: :destroy

  private

  def fetch_and_summarize
    FetchLinkPreviewJob.perform_later(id)
  end

  def trigger_summary
    CampaignSummaryJob.perform_later(campaign_id)
  end
end
