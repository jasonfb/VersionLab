class CreateInvoiceLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_line_items, id: :uuid do |t|
      t.uuid :invoice_id, null: false
      t.enum :kind, enum_type: :invoice_line_item_kind, null: false
      t.string :description, null: false
      t.integer :quantity, null: false, default: 1
      t.integer :unit_amount_cents, null: false, default: 0
      t.integer :amount_cents, null: false, default: 0
      t.timestamps
    end

    add_index :invoice_line_items, :invoice_id
    add_foreign_key :invoice_line_items, :invoices
  end
end
