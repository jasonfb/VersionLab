require 'rails_helper'

RSpec.describe InvoiceLineItem, type: :model do
  describe "associations" do
    it "belongs to invoice" do
      assoc = described_class.reflect_on_association(:invoice)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires description" do
      item = build(:invoice_line_item, description: nil)
      expect(item).not_to be_valid
      expect(item.errors[:description]).to include("can't be blank")
    end

    it "requires quantity to be a non-negative integer" do
      item = build(:invoice_line_item, quantity: -1)
      expect(item).not_to be_valid
      expect(item.errors[:quantity]).to include("must be greater than or equal to 0")
    end

    it "rejects non-integer quantity" do
      item = build(:invoice_line_item, quantity: 1.5)
      expect(item).not_to be_valid
      expect(item.errors[:quantity]).to include("must be an integer")
    end

    it "allows zero quantity" do
      item = build(:invoice_line_item, quantity: 0)
      expect(item).to be_valid
    end
  end

  describe "enums" do
    it "defines kind enum with prefix" do
      expect(described_class.kinds).to eq(
        "subscription" => "subscription", "overage" => "overage",
        "credit" => "credit", "adjustment" => "adjustment"
      )
    end

    it "responds to prefixed kind methods" do
      item = build(:invoice_line_item, kind: "subscription")
      expect(item.kind_subscription?).to be true
      expect(item.kind_overage?).to be false
    end
  end
end
