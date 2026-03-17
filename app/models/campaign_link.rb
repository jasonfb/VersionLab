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
