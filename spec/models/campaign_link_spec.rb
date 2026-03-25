require 'rails_helper'

RSpec.describe CampaignLink, type: :model do
  describe "associations" do
    it "belongs to campaign" do
      assoc = described_class.reflect_on_association(:campaign)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires a url" do
      link = build(:campaign_link, url: nil)
      expect(link).not_to be_valid
      expect(link.errors[:url]).to include("can't be blank")
    end
  end
end
