require 'rails_helper'

RSpec.describe CampaignDocument, type: :model do
  describe "associations" do
    it "belongs to campaign" do
      assoc = described_class.reflect_on_association(:campaign)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires a display_name" do
      doc = build(:campaign_document, display_name: nil)
      expect(doc).not_to be_valid
      expect(doc.errors[:display_name]).to include("can't be blank")
    end
  end
end
