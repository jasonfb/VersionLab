# frozen_string_literal: true

# == Schema Information
#
# Table name: accounts
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  is_agency          :boolean          default(FALSE), not null
#  name               :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  stripe_customer_id :string
#
# Indexes
#
#  index_accounts_on_stripe_customer_id  (stripe_customer_id) UNIQUE
#
class Account < ApplicationRecord
  belongs_to :ai_service, optional: true
  belongs_to :ai_model, optional: true

  has_many :clients, dependent: :destroy
  has_many :account_users, dependent: :destroy
  has_many :users, through: :account_users
  has_many :ai_logs, dependent: :destroy
  has_many :ai_usage_summaries, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :payment_methods, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :invoices, dependent: :destroy

  scope :reverse_sort, -> { order(created_at:  :desc) }

  def default_client
    clients.find_by(hidden: true)
  end

  def active_subscription
    subscriptions.active.first
  end

  def default_payment_method
    payment_methods.find_by(is_default: true) || payment_methods.first
  end

  def on_free_trial?
    active_subscription&.subscription_tier&.slug == "free_trial"
  end

  def on_demo?
    active_subscription&.subscription_tier&.slug == "demo"
  end

  def trial_expired?
    sub = active_subscription
    return false unless sub
    sub.trial_or_demo? && sub.paid_through_date < Date.current
  end

  # Returns true when a demo or free-trial account has exhausted its 250
  # VL-token allotment OR its time window has expired.
  def account_locked_out?
    sub = active_subscription
    return false unless sub
    return false unless sub.trial_or_demo?

    trial_expired? || sub.current_cycle_vl_tokens_used >= sub.effective_monthly_token_allotment
  end
end
