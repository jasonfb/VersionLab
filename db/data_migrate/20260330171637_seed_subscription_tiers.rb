class SeedSubscriptionTiers < ActiveRecord::Migration[8.1]
  def up
    SubscriptionTier.find_or_create_by!(slug: "standard") do |tier|
      tier.name = "Standard"
      tier.monthly_price_cents = 4900
      tier.annual_price_cents = 49900
      tier.position = 0
    end

    SubscriptionTier.find_or_create_by!(slug: "agency") do |tier|
      tier.name = "Agency"
      tier.monthly_price_cents = 9900
      tier.annual_price_cents = 99900
      tier.position = 1
    end
  end

  def down
    SubscriptionTier.where(slug: %w[standard agency]).destroy_all
  end
end
