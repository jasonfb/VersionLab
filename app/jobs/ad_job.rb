class AdJob < ApplicationJob
  queue_as :default

  def perform(ad_id, audience_id: nil, rejection_comment: nil)
    ad = Ad.find(ad_id)

    audience_ids = audience_id ? [ audience_id ] : nil
    rejection_context = (audience_id && rejection_comment) ? { audience_id => rejection_comment } : {}

    AdMergeService.new(ad, audience_ids: audience_ids, rejection_context: rejection_context).call
    ad.update!(state: :merged)
    broadcast(ad, :merged)
  rescue AdMergeService::Error => e
    Rails.logger.error("AdJob failed for ad #{ad_id}: #{e.message}")
    handle_failure(ad, audience_id)
  rescue StandardError => e
    Rails.logger.error("AdJob unexpected error for ad #{ad_id}: #{e.message}")
    handle_failure(ad, audience_id)
    raise
  end

  private

  def handle_failure(ad, audience_id)
    return unless ad
    ad.ad_versions.where(audience_id: audience_id, state: :generating).destroy_all if audience_id
    new_state = ad.ad_versions.active.any? ? :merged : :setup
    ad.update!(state: new_state)
    broadcast(ad, new_state)
  end

  def broadcast(ad, state)
    ActionCable.server.broadcast("ad:#{ad.id}", { state: state.to_s, ad_id: ad.id })
  end
end
