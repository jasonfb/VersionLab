FactoryBot.define do
  factory :invoice do
    account
    status { "draft" }
    sequence(:invoice_number) { |n| "INV-2026-#{format('%08X', n)}" }
  end
end
