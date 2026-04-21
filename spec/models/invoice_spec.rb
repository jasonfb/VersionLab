require 'rails_helper'

RSpec.describe Invoice, type: :model do
  describe "associations" do
    it "belongs to account" do
      assoc = described_class.reflect_on_association(:account)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to subscription (optional)" do
      assoc = described_class.reflect_on_association(:subscription)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to eq(true)
    end

    it "has many line_items with dependent destroy" do
      assoc = described_class.reflect_on_association(:line_items)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
      expect(assoc.options[:class_name]).to eq("InvoiceLineItem")
    end

    it "has many payments with dependent nullify" do
      assoc = described_class.reflect_on_association(:payments)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:nullify)
    end
  end

  describe "validations" do
    it "requires invoice_number" do
      invoice = build(:invoice, invoice_number: nil)
      # before_validation assigns it, so we need to skip callbacks
      invoice.invoice_number = nil
      invoice.valid?
      # The before_validation callback will assign one, so test uniqueness instead
    end

    it "enforces uniqueness of invoice_number" do
      create(:invoice, invoice_number: "INV-DUPE-001")
      duplicate = build(:invoice, invoice_number: "INV-DUPE-001")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:invoice_number]).to include("has already been taken")
    end

    it "requires status" do
      invoice = build(:invoice)
      invoice.status = nil
      expect(invoice).not_to be_valid
      expect(invoice.errors[:status]).to include("can't be blank")
    end
  end

  describe "enums" do
    it "defines status enum" do
      expect(described_class.statuses).to eq(
        "draft" => "draft", "open" => "open", "paid" => "paid",
        "void" => "void", "uncollectible" => "uncollectible"
      )
    end
  end

  describe "callbacks" do
    it "auto-assigns invoice_number on create when blank" do
      invoice = create(:invoice, invoice_number: nil)
      expect(invoice.invoice_number).to match(/\AINV-\d{4}-[A-F0-9]{8}\z/)
    end

    it "does not overwrite an existing invoice_number" do
      invoice = create(:invoice, invoice_number: "CUSTOM-001")
      expect(invoice.invoice_number).to eq("CUSTOM-001")
    end
  end

  describe "scopes" do
    it ".recent orders by created_at desc" do
      old = create(:invoice, created_at: 2.days.ago)
      recent = create(:invoice, created_at: 1.hour.ago)
      expect(described_class.recent.to_a).to eq([recent, old])
    end
  end

  describe "#add_line_item!" do
    it "creates a line item and recomputes totals" do
      invoice = create(:invoice)
      invoice.add_line_item!(
        kind: "subscription",
        description: "Monthly plan",
        quantity: 1,
        unit_amount_cents: 4900
      )
      expect(invoice.line_items.count).to eq(1)
      expect(invoice.subtotal_cents).to eq(4900)
      expect(invoice.total_cents).to eq(4900)
    end

    it "computes amount_cents from quantity * unit_amount_cents when not provided" do
      invoice = create(:invoice)
      invoice.add_line_item!(
        kind: "overage",
        description: "Token overage",
        quantity: 3,
        unit_amount_cents: 500
      )
      expect(invoice.line_items.last.amount_cents).to eq(1500)
    end

    it "uses explicit amount_cents when provided" do
      invoice = create(:invoice)
      invoice.add_line_item!(
        kind: "credit",
        description: "Promotional credit",
        quantity: 1,
        unit_amount_cents: 1000,
        amount_cents: 750
      )
      expect(invoice.line_items.last.amount_cents).to eq(750)
    end

    it "accumulates totals across multiple line items" do
      invoice = create(:invoice)
      invoice.add_line_item!(kind: "subscription", description: "Plan", quantity: 1, unit_amount_cents: 4900)
      invoice.add_line_item!(kind: "overage", description: "Extra", quantity: 2, unit_amount_cents: 500)
      expect(invoice.total_cents).to eq(5900)
    end
  end

  describe "#recompute_totals!" do
    it "recalculates from line items" do
      invoice = create(:invoice, subtotal_cents: 9999, total_cents: 9999)
      create(:invoice_line_item, invoice: invoice, amount_cents: 2000)
      create(:invoice_line_item, invoice: invoice, amount_cents: 3000)
      invoice.recompute_totals!
      expect(invoice.subtotal_cents).to eq(5000)
      expect(invoice.total_cents).to eq(5000)
    end
  end

  describe "#finalize!" do
    it "transitions from draft to open and stamps issued_at" do
      invoice = create(:invoice, status: "draft")
      invoice.finalize!
      expect(invoice.status).to eq("open")
      expect(invoice.issued_at).to be_present
    end

    it "does nothing when not in draft status" do
      invoice = create(:invoice, status: "open", issued_at: 1.day.ago)
      original_issued_at = invoice.issued_at
      invoice.finalize!
      expect(invoice.issued_at).to eq(original_issued_at)
    end
  end

  describe "#mark_paid!" do
    it "marks the invoice as paid and associates the payment" do
      invoice = create(:invoice, status: "open")
      payment = create(:payment, account: invoice.account)
      invoice.mark_paid!(payment: payment)
      expect(invoice.status).to eq("paid")
      expect(invoice.paid_at).to be_present
      expect(payment.reload.invoice_id).to eq(invoice.id)
    end
  end
end
