class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_enum :payment_status, ["succeeded", "failed", "pending", "refunded"]

    create_table :payments, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :subscription_id
      t.uuid :payment_method_id
      t.string :stripe_payment_intent_id
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "usd"
      t.enum :status, enum_type: :payment_status, null: false
      t.string :description
      t.text :failure_reason
      t.timestamps
    end

    add_index :payments, :account_id
    add_index :payments, :subscription_id
    add_index :payments, :stripe_payment_intent_id, unique: true
  end
end
