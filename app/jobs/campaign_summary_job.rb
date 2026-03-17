class CampaignSummaryJob < ApplicationJob
  queue_as :default

  def perform(campaign_id)
    campaign = Campaign.find_by(id: campaign_id)
    return unless campaign

    campaign.update!(ai_summary_state: :generating)

    summary = CampaignSummaryService.new(campaign).call

    campaign.update!(
      ai_summary: summary,
      ai_summary_state: :generated,
      ai_summary_generated_at: Time.current
    )
  rescue CampaignSummaryService::Error => e
    Rails.logger.error("CampaignSummaryJob failed for campaign #{campaign_id}: #{e.message}")
    campaign&.update!(ai_summary_state: :failed)
  rescue StandardError => e
    Rails.logger.error("CampaignSummaryJob unexpected error for campaign #{campaign_id}: #{e.message}")
    campaign&.update!(ai_summary_state: :failed)
    raise
  end
end
