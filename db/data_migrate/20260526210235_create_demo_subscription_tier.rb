class CreateDemoSubscriptionTier < ActiveRecord::Migration[8.1]
  def up
    # Create the "Demo" tier: 250 VL tokens, 1-day window, $0
    SubscriptionTier.find_or_create_by!(slug: "demo") do |tier|
      tier.name = "Demo"
      tier.monthly_price_cents = 0
      tier.annual_price_cents = 0
      tier.monthly_token_allotment = 250
      tier.overage_cents_per_1000_tokens = 0
      tier.position = -1 # before free_trial
    end

    # Update Free Trial tier to 250 tokens (was 1000)
    free_trial = SubscriptionTier.find_by(slug: "free_trial")
    free_trial&.update!(monthly_token_allotment: 250)
  end

  def down
    SubscriptionTier.find_by(slug: "demo")&.destroy
    free_trial = SubscriptionTier.find_by(slug: "free_trial")
    free_trial&.update!(monthly_token_allotment: 1000)
  end
end
