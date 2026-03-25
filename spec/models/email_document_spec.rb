require 'rails_helper'

RSpec.describe EmailDocument, type: :model do
  before do
    allow(EmailSummaryJob).to receive(:perform_later)
  end

  describe "associations" do
    it "belongs to email" do
      assoc = described_class.reflect_on_association(:email)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires display_name" do
      doc = build(:email_document, display_name: nil)
      expect(doc).not_to be_valid
      expect(doc.errors[:display_name]).to include("can't be blank")
    end
  end
end
