class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :subscription_id
      t.string :invoice_number, null: false
      t.enum :status, enum_type: :invoice_status, null: false, default: "draft"
      t.date :period_start
      t.date :period_end
      t.integer :subtotal_cents, null: false, default: 0
      t.integer :total_cents, null: false, default: 0
      t.datetime :issued_at
      t.datetime :paid_at
      t.datetime :email_sent_at
      t.timestamps
    end

    add_index :invoices, :invoice_number, unique: true
    add_index :invoices, :account_id
    add_index :invoices, :subscription_id
    add_foreign_key :invoices, :accounts
    add_foreign_key :invoices, :subscriptions
  end
end
