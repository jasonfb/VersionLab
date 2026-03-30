FactoryBot.define do
  factory :subscription_tier do
    name { "Standard" }
    sequence(:slug) { |n| "standard-#{n}" }
    monthly_price_cents { 4900 }
    annual_price_cents { 49900 }
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
