require 'rails_helper'

RSpec.describe VlToken do
  describe "constants" do
    it "defines conversion rates" do
      expect(VlToken::CENTS_PER_DOLLAR).to eq(100)
      expect(VlToken::TOKENS_PER_DOLLAR).to eq(1000)
      expect(VlToken::TOKENS_PER_CENT).to eq(10)
    end

    it "defines default allotment and overage rate" do
      expect(VlToken::DEFAULT_MONTHLY_ALLOTMENT).to eq(1000)
      expect(VlToken::DEFAULT_OVERAGE_CENTS_PER_1000_TOKENS).to eq(500)
    end
  end

  describe ".from_cost_cents" do
    it "converts cents to VL tokens" do
      expect(VlToken.from_cost_cents(1)).to eq(10)
      expect(VlToken.from_cost_cents(100)).to eq(1000)
    end

    it "handles zero" do
      expect(VlToken.from_cost_cents(0)).to eq(0)
    end

    it "converts non-integer input via to_i" do
      expect(VlToken.from_cost_cents(5.9)).to eq(50)
    end

    it "handles nil via to_i" do
      expect(VlToken.from_cost_cents(nil)).to eq(0)
    end
  end

  describe ".overage_cents" do
    it "calculates overage charge for given tokens and rate" do
      # 500 tokens at 500 cents per 1000 = 250 cents
      expect(VlToken.overage_cents(500, 500)).to eq(250)
    end

    it "rounds up to the nearest cent" do
      # 1 token at 500 cents per 1000 = 0.5 → ceil to 1
      expect(VlToken.overage_cents(1, 500)).to eq(1)
    end

    it "returns 0 for zero overage tokens" do
      expect(VlToken.overage_cents(0, 500)).to eq(0)
    end

    it "returns 0 for negative overage tokens" do
      expect(VlToken.overage_cents(-10, 500)).to eq(0)
    end

    it "handles nil inputs" do
      expect(VlToken.overage_cents(nil, 500)).to eq(0)
      expect(VlToken.overage_cents(100, nil)).to eq(0)
    end

    it "calculates correctly for large token counts" do
      # 10000 tokens at 500 cents per 1000 = 5000 cents
      expect(VlToken.overage_cents(10_000, 500)).to eq(5000)
    end
  end
end
