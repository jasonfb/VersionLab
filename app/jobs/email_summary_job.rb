class EmailSummaryJob < ApplicationJob
  queue_as :default

  def perform(email_id)
    email = Email.find_by(id: email_id)
    return unless email

    email.update!(ai_summary_state: :generating)

    summary = EmailSummaryService.new(email).call

    email.update!(
      ai_summary: summary,
      ai_summary_state: :generated,
      ai_summary_generated_at: Time.current
    )
  rescue EmailSummaryService::Error => e
    Rails.logger.error("EmailSummaryJob failed for email #{email_id}: #{e.message}")
    email&.update!(ai_summary_state: :failed)
    raise
  rescue StandardError => e
    Rails.logger.error("EmailSummaryJob unexpected error for email #{email_id}: #{e.message}")
    email&.update!(ai_summary_state: :failed)
    raise
  end
end
