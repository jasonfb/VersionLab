class CreateInvoiceStatusEnum < ActiveRecord::Migration[8.1]
  def change
    create_enum :invoice_status, %w[draft open paid void uncollectible]
  end
end
