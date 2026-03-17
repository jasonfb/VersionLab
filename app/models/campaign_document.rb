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
