class CreateInvoiceLineItemKindEnum < ActiveRecord::Migration[8.1]
  def change
    create_enum :invoice_line_item_kind, %w[subscription overage credit adjustment]
  end
end
