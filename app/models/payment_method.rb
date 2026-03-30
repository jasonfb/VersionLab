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
