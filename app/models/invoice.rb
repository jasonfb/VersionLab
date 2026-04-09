# == Schema Information
#
# Table name: invoices
#
#  id              :uuid             not null, primary key
#  account_id      :uuid             not null
#  subscription_id :uuid
#  invoice_number  :string           not null
#  status          :enum             not null, default("draft")
#  period_start    :date
#  period_end      :date
#  subtotal_cents  :integer          not null, default(0)
#  total_cents     :integer          not null, default(0)
#  issued_at       :datetime
#  paid_at         :datetime
#  email_sent_at   :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Invoice < ApplicationRecord
  belongs_to :account
  belongs_to :subscription, optional: true
  has_many :line_items, -> { order(created_at: :asc) }, class_name: "InvoiceLineItem", dependent: :destroy
  has_many :payments, dependent: :nullify

  enum :status, { draft: "draft", open: "open", paid: "paid", void: "void", uncollectible: "uncollectible" }

  validates :invoice_number, presence: true, uniqueness: true
  validates :status, presence: true

  before_validation :assign_invoice_number, on: :create

  scope :recent, -> { order(created_at: :desc) }

  # Append a line item and recompute totals.
  def add_line_item!(kind:, description:, quantity: 1, unit_amount_cents:, amount_cents: nil)
    amount = amount_cents || (quantity * unit_amount_cents)
    line_items.create!(
      kind: kind,
      description: description,
      quantity: quantity,
      unit_amount_cents: unit_amount_cents,
      amount_cents: amount
    )
    recompute_totals!
  end

  def recompute_totals!
    sub = line_items.sum(:amount_cents)
    update!(subtotal_cents: sub, total_cents: sub)
  end

  # Move from draft → open and stamp issued_at.
  def finalize!
    return unless draft?
    update!(status: "open", issued_at: Time.current)
  end

  def mark_paid!(payment:)
    update!(status: "paid", paid_at: Time.current)
    payment.update!(invoice_id: id)
  end

  private

  def assign_invoice_number
    return if invoice_number.present?
    self.invoice_number = "INV-#{Date.current.year}-#{SecureRandom.hex(4).upcase}"
  end
end
