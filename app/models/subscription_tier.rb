class SubscriptionTier < ApplicationRecord
  has_many :subscriptions, dependent: :restrict_with_error

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :monthly_price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :annual_price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def monthly_price
    monthly_price_cents / 100.0
  end

  def annual_price
    annual_price_cents / 100.0
  end
end
