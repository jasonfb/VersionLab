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

  # AI model categories:
  #   email_copy        — email template copy generation
  #   ad_classification — ad element role classification + text correction
  #   ad_vision         — face/subject detection in backgrounds
  #   ad_copy           — ad copy generation for versioning
  #   ad_layout         — text reflow/positioning
  AI_MODEL_CATEGORIES = %w[email_copy ad_classification ad_vision ad_copy ad_layout].freeze

  # Resolve the AI model for a given usage category.
  # Priority: category-specific preference → ad-level override → account global default → first available
  def ai_model_for(category, ad: nil)
    # 1. Category-specific preference
    pref_model_id = ai_model_preferences&.dig(category.to_s, "ai_model_id")
    if pref_model_id.present?
      model = AiModel.find_by(id: pref_model_id)
      return model if model && AiKey.exists?(ai_service_id: model.ai_service_id)
    end

    # 2. Ad-level override
    if ad&.ai_model && AiKey.exists?(ai_service_id: ad.ai_model.ai_service_id)
      return ad.ai_model
    end

    # 3. Account global default
    if ai_model && AiKey.exists?(ai_service_id: ai_model.ai_service_id)
      return ai_model
    end

    # 4. First available model with a key
    service_ids = AiKey.pluck(:ai_service_id)
    AiModel.where(ai_service_id: service_ids).order(:created_at).first
  end

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
