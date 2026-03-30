class Subscription < ApplicationRecord
  belongs_to :account
  belongs_to :subscription_tier

  enum :billing_interval, { monthly: "monthly", annual: "annual" }

  validates :billing_interval, presence: true
  validates :start_date, presence: true
  validates :paid_through_date, presence: true

  has_many :payments, dependent: :nullify

  scope :active, -> { where(canceled_date: nil) }
  scope :canceled, -> { where.not(canceled_date: nil) }

  def active?
    canceled_date.nil?
  end

  def canceled?
    canceled_date.present?
  end

  def current_period_price_cents
    monthly? ? subscription_tier.monthly_price_cents : subscription_tier.annual_price_cents
  end

  def free_trial?
    subscription_tier.slug == "free_trial"
  end

  def overdue?
    active? && !free_trial? && paid_through_date < Date.current
  end
end
