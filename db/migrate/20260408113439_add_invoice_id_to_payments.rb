class AddInvoiceIdToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :invoice_id, :uuid
    add_index :payments, :invoice_id
  end
end
