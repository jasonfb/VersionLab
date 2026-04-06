# == Schema Information
#
# Table name: campaigns
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  ai_summary              :text
#  ai_summary_generated_at :datetime
#  ai_summary_state        :enum             default("idle"), not null
#  description             :text
#  end_date                :date
#  goals                   :text
#  name                    :string           not null
#  start_date              :date
#  status                  :enum             default("draft"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  client_id               :uuid             not null
#
# Indexes
#
#  index_campaigns_on_client_id  (client_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_id => clients.id)
#
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
