class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_enum :subscription_billing_interval, ["monthly", "annual"]

    create_table :subscriptions, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :subscription_tier_id, null: false
      t.enum :billing_interval, enum_type: :subscription_billing_interval, null: false
      t.date :start_date, null: false
      t.date :paid_through_date, null: false
      t.date :canceled_date
      t.integer :prorated_refund_cents
      t.integer :credit_applied_cents
      t.timestamps
    end

    add_index :subscriptions, :account_id
    add_index :subscriptions, :subscription_tier_id
  end
end
