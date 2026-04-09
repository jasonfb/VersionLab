# VersionLab Tokens — internal abstraction over real AI spend.
#
# Conversion: 1000 VL tokens = $1.00 of our actual AI cost.
# Therefore: 1 VL token = 0.1 cents, and 1 cent of cost = 10 VL tokens.
#
# Default plan allotment: 1000 VL tokens / month (configurable per
# SubscriptionTier and overridable per Subscription).
# Default overage rate: $0.005 / VL token = 500 cents per 1000 tokens
# (5x our actual cost — never disclosed to customers).
module VlToken
  CENTS_PER_DOLLAR = 100
  TOKENS_PER_DOLLAR = 1000
  TOKENS_PER_CENT = TOKENS_PER_DOLLAR / CENTS_PER_DOLLAR # = 10

  DEFAULT_MONTHLY_ALLOTMENT = 1000
  DEFAULT_OVERAGE_CENTS_PER_1000_TOKENS = 500

  # Convert an internal AI cost (in integer cents) into VL tokens.
  def self.from_cost_cents(cents)
    cents.to_i * TOKENS_PER_CENT
  end

  # Compute the overage charge in cents for a given number of overage
  # tokens, using the per-1000 rate stored on the SubscriptionTier.
  def self.overage_cents(overage_tokens, cents_per_1000_tokens)
    return 0 if overage_tokens.to_i <= 0
    ((overage_tokens.to_i * cents_per_1000_tokens.to_i) / 1000.0).ceil
  end
end
