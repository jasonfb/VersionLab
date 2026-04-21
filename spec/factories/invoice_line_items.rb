FactoryBot.define do
  factory :invoice_line_item do
    invoice
    kind { "subscription" }
    description { "Monthly subscription" }
    quantity { 1 }
    unit_amount_cents { 4900 }
    amount_cents { 4900 }
  end
end
