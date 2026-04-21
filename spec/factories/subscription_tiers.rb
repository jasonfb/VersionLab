# == Schema Information
#
# Table name: subscription_tiers
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  annual_price_cents  :integer          not null
#  monthly_price_cents :integer          not null
#  name                :string           not null
#  position            :integer          default(0), not null
#  slug                :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_subscription_tiers_on_slug  (slug) UNIQUE
#
FactoryBot.define do
  factory :subscription_tier do
    name { "Standard" }
    sequence(:slug) { |n| "standard-#{n}" }
    monthly_price_cents { 4900 }
    annual_price_cents { 49900 }
    monthly_token_allotment { 1000 }
    overage_cents_per_1000_tokens { 500 }
    position { 0 }

    trait :agency do
      name { "Agency" }
      slug { "agency" }
      monthly_price_cents { 9900 }
      annual_price_cents { 99900 }
      position { 1 }
    end
  end
end
