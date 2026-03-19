class EmailJob < ApplicationJob
  queue_as :default

  def perform(email_id, audience_id: nil, rejection_comment: nil)
    email = Email.find(email_id)

    audience_ids = audience_id ? [audience_id] : nil
    rejection_context = (audience_id && rejection_comment) ? { audience_id => rejection_comment } : {}

    AiMergeService.new(email, audience_ids: audience_ids, rejection_context: rejection_context).call
    email.update!(state: :merged)
    broadcast(email, :merged)
  rescue AiMergeService::Error => e
    Rails.logger.error("EmailJob failed for email #{email_id}: #{e.message}")
    handle_failure(email, audience_id)
  rescue StandardError => e
    Rails.logger.error("EmailJob unexpected error for email #{email_id}: #{e.message}")
    handle_failure(email, audience_id)
    raise
  end

  private

  def handle_failure(email, audience_id)
    return unless email
    email.email_versions.where(audience_id: audience_id, state: :generating).destroy_all if audience_id
    new_state = email.email_versions.active.any? ? :merged : :setup
    email.update!(state: new_state)
    broadcast(email, new_state)
  end

  def broadcast(email, state)
    ActionCable.server.broadcast("email:#{email.id}", { state: state.to_s, email_id: email.id })
  end
end
