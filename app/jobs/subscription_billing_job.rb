# Daily sweep that delegates each subscription to BillingService.
#
# Picks up two states:
#   * active, non-trial subs (renewals + token-cycle overage)
#   * canceled subs that haven't been final-billed yet
#
# Free trials are skipped — they don't bill, and any AI usage during a
# trial is uncharged.
class SubscriptionBillingJob < ApplicationJob
  queue_as :default

  def perform
    Subscription
      .joins(:subscription_tier)
      .where.not(subscription_tiers: { slug: "free_trial" })
      .where("subscriptions.canceled_date IS NULL OR subscriptions.final_billed_at IS NULL")
      .includes(:account, :subscription_tier)
      .find_each do |subscription|
        BillingService.process(subscription)
      rescue StandardError => e
        Rails.logger.error("SubscriptionBillingJob: error processing #{subscription.id}: #{e.message}")
      end
  end
end
