class SeedFreeTrialTier < ActiveRecord::Migration[8.1]
  def up
    SubscriptionTier.find_or_create_by!(slug: "free_trial") do |tier|
      tier.name = "Free Trial"
      tier.monthly_price_cents = 0
      tier.annual_price_cents = 0
      tier.position = -1
    end
  end

  def down
    SubscriptionTier.find_by(slug: "free_trial")&.destroy
  end
end
