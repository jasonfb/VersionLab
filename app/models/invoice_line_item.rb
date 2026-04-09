# == Schema Information
#
# Table name: invoice_line_items
#
#  id                :uuid             not null, primary key
#  invoice_id        :uuid             not null
#  kind              :enum             not null
#  description       :string           not null
#  quantity          :integer          not null, default(1)
#  unit_amount_cents :integer          not null, default(0)
#  amount_cents      :integer          not null, default(0)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class InvoiceLineItem < ApplicationRecord
  belongs_to :invoice

  enum :kind, { subscription: "subscription", overage: "overage", credit: "credit", adjustment: "adjustment" }, prefix: true

  validates :description, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0, only_integer: true }
end
