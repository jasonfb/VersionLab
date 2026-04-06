# == Schema Information
#
# Table name: payment_methods
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  card_brand               :string
#  card_exp_month           :integer
#  card_exp_year            :integer
#  card_last4               :string
#  is_default               :boolean          default(FALSE), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :uuid             not null
#  stripe_payment_method_id :string           not null
#
# Indexes
#
#  index_payment_methods_on_account_id                (account_id)
#  index_payment_methods_on_stripe_payment_method_id  (stripe_payment_method_id) UNIQUE
#
class PaymentMethod < ApplicationRecord
  belongs_to :account
  has_many :payments, dependent: :nullify

  validates :stripe_payment_method_id, presence: true, uniqueness: true

  scope :default_method, -> { where(is_default: true) }

  def display_name
    brand = card_brand&.capitalize || "Card"
    "#{brand} ending in #{card_last4}"
  end
end
