class AudienceSummaryJob < ApplicationJob
  queue_as :default

  def perform(audience_id)
    audience = Audience.find_by(id: audience_id)
    return unless audience

    audience.update!(ai_summary_state: :generating)

    result = AudienceSummaryService.new(audience).call

    audience.update!(
      **result,
      ai_summary_state: :generated,
      ai_summary_generated_at: Time.current
    )
  rescue AudienceSummaryService::Error => e
    Rails.logger.error("AudienceSummaryJob failed for audience #{audience_id}: #{e.message}")
    audience&.update!(ai_summary_state: :failed)
    raise
  rescue StandardError => e
    Rails.logger.error("AudienceSummaryJob unexpected error for audience #{audience_id}: #{e.message}")
    audience&.update!(ai_summary_state: :failed)
    raise
  end
end
