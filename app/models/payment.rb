class Payment < ApplicationRecord
  belongs_to :account
  belongs_to :subscription, optional: true
  belongs_to :payment_method, optional: true

  enum :status, { succeeded: "succeeded", failed: "failed", pending: "pending", refunded: "refunded" }

  validates :amount_cents, presence: true
  validates :status, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
