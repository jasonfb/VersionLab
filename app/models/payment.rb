# == Schema Information
#
# Table name: payments
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  amount_cents             :integer          not null
#  currency                 :string           default("usd"), not null
#  description              :string
#  failure_reason           :text
#  status                   :enum             not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :uuid             not null
#  payment_method_id        :uuid
#  stripe_payment_intent_id :string
#  subscription_id          :uuid
#
# Indexes
#
#  index_payments_on_account_id                (account_id)
#  index_payments_on_stripe_payment_intent_id  (stripe_payment_intent_id) UNIQUE
#  index_payments_on_subscription_id           (subscription_id)
#
class Payment < ApplicationRecord
  belongs_to :account
  belongs_to :subscription, optional: true
  belongs_to :payment_method, optional: true
  belongs_to :invoice, optional: true

  enum :status, { succeeded: "succeeded", failed: "failed", pending: "pending", refunded: "refunded" }

  validates :amount_cents, presence: true
  validates :status, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
