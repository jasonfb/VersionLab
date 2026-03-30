class Account < ApplicationRecord
  has_many :clients, dependent: :destroy
  has_many :account_users, dependent: :destroy
  has_many :users, through: :account_users
  has_many :ai_keys, dependent: :destroy
  has_many :ai_logs, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :payment_methods, dependent: :destroy
  has_many :payments, dependent: :destroy

  def default_client
    clients.find_by(hidden: true)
  end

  def active_subscription
    subscriptions.active.includes(:subscription_tier).first
  end

  def default_payment_method
    payment_methods.find_by(is_default: true) || payment_methods.first
  end

  def on_free_trial?
    active_subscription&.subscription_tier&.slug == "free_trial"
  end

  def trial_expired?
    sub = active_subscription
    return false unless sub
    sub.free_trial? && sub.paid_through_date < Date.current
  end
end
