require 'rails_helper'

RSpec.describe Campaign, type: :model do
  describe "associations" do
    it "belongs to client" do
      assoc = described_class.reflect_on_association(:client)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "has many campaign_documents with dependent destroy" do
      assoc = described_class.reflect_on_association(:campaign_documents)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many campaign_links with dependent destroy" do
      assoc = described_class.reflect_on_association(:campaign_links)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end
  end

  describe "validations" do
    it "requires a name" do
      campaign = build(:campaign, name: nil)
      expect(campaign).not_to be_valid
      expect(campaign.errors[:name]).to include("can't be blank")
    end
  end

  describe "enums" do
    it "defines status enum" do
      expect(described_class.statuses).to eq(
        "draft" => "draft", "active" => "active", "completed" => "completed", "archived" => "archived"
      )
    end

    it "defines ai_summary_state enum" do
      expect(described_class.ai_summary_states).to eq(
        "idle" => "idle", "generating" => "generating", "generated" => "generated", "failed" => "failed"
      )
    end
  end
end
