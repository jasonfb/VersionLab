class AddTokenAllotmentToSubscriptionTiers < ActiveRecord::Migration[8.1]
  def change
    add_column :subscription_tiers, :monthly_token_allotment, :integer, null: false, default: 1000
    add_column :subscription_tiers, :overage_cents_per_1000_tokens, :integer, null: false, default: 500
  end
end
