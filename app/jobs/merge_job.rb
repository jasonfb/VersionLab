class MergeJob < ApplicationJob
  queue_as :default

  def perform(merge_id, audience_id: nil, rejection_comment: nil)
    merge = Merge.find(merge_id)

    audience_ids = audience_id ? [audience_id] : nil
    rejection_context = (audience_id && rejection_comment) ? { audience_id => rejection_comment } : {}

    AiMergeService.new(merge, audience_ids: audience_ids, rejection_context: rejection_context).call
    merge.update!(state: :merged)
    broadcast(merge, :merged)
  rescue AiMergeService::Error => e
    Rails.logger.error("MergeJob failed for merge #{merge_id}: #{e.message}")
    handle_failure(merge, audience_id)
  rescue StandardError => e
    Rails.logger.error("MergeJob unexpected error for merge #{merge_id}: #{e.message}")
    handle_failure(merge, audience_id)
    raise
  end

  private

  def handle_failure(merge, audience_id)
    return unless merge
    merge.merge_versions.where(audience_id: audience_id, state: :generating).destroy_all if audience_id
    new_state = merge.merge_versions.active.any? ? :merged : :setup
    merge.update!(state: new_state)
    broadcast(merge, new_state)
  end

  def broadcast(merge, state)
    ActionCable.server.broadcast("merge:#{merge.id}", { state: state.to_s, merge_id: merge.id })
  end
end
