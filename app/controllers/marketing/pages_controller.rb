class Marketing::PagesController < ApplicationController
  layout "marketing"

  def home
  end

  def pricing
    @subscription_tiers = SubscriptionTier.where.not(slug: "free_trial").order(:position, :monthly_price_cents)
  end

  def contact
  end
end
