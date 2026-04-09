class AddTokenAllotmentOverrideToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :monthly_token_allotment_override, :integer
  end
end
