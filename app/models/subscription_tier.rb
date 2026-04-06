# == Schema Information
#
# Table name: subscription_tiers
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  annual_price_cents  :integer          not null
#  monthly_price_cents :integer          not null
#  name                :string           not null
#  position            :integer          default(0), not null
#  slug                :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_subscription_tiers_on_slug  (slug) UNIQUE
#
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
