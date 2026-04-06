# == Schema Information
#
# Table name: emails
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  ai_summary              :text
#  ai_summary_generated_at :datetime
#  ai_summary_state        :enum             default("idle"), not null
#  context                 :text
#  state                   :enum             default("setup"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  ai_model_id             :uuid
#  ai_service_id           :uuid
#  campaign_id             :uuid
#  client_id               :uuid             not null
#  email_template_id       :uuid             not null
#
# Indexes
#
#  index_emails_on_campaign_id  (campaign_id)
#  index_emails_on_client_id    (client_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#  fk_rails_...  (client_id => clients.id)
#
require 'rails_helper'

RSpec.describe Email, type: :model do
  describe "associations" do
    it "belongs to client" do
      assoc = described_class.reflect_on_association(:client)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to email_template" do
      assoc = described_class.reflect_on_association(:email_template)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to campaign (optional)" do
      assoc = described_class.reflect_on_association(:campaign)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to eq(true)
    end

    it "belongs to ai_service (optional)" do
      assoc = described_class.reflect_on_association(:ai_service)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to eq(true)
    end

    it "belongs to ai_model (optional)" do
      assoc = described_class.reflect_on_association(:ai_model)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to eq(true)
    end

    it "has many email_audiences" do
      assoc = described_class.reflect_on_association(:email_audiences)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many audiences through email_audiences" do
      assoc = described_class.reflect_on_association(:audiences)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:email_audiences)
    end

    it "has many email_versions" do
      assoc = described_class.reflect_on_association(:email_versions)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many email_documents" do
      assoc = described_class.reflect_on_association(:email_documents)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many email_section_autolink_settings" do
      assoc = described_class.reflect_on_association(:email_section_autolink_settings)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end
  end

  describe "validations" do
    it "allows blank context" do
      email = build(:email, context: "")
      email.valid?
      expect(email.errors[:context]).to be_empty
    end

    it "allows nil context" do
      email = build(:email, context: nil)
      email.valid?
      expect(email.errors[:context]).to be_empty
    end

    it "rejects context longer than 5000 characters" do
      email = build(:email, context: "a" * 5001)
      expect(email).not_to be_valid
      expect(email.errors[:context]).to be_present
    end

    it "accepts context of exactly 5000 characters" do
      email = build(:email, context: "a" * 5000)
      email.valid?
      expect(email.errors[:context]).to be_empty
    end
  end

  describe "enums" do
    it "defines state enum" do
      expect(described_class.states).to eq(
        "setup" => "setup",
        "pending" => "pending",
        "merged" => "merged",
        "regenerating" => "regenerating"
      )
    end

    it "defines ai_summary_state enum with summary prefix" do
      expect(described_class.ai_summary_states).to eq(
        "idle" => "idle",
        "generating" => "generating",
        "generated" => "generated",
        "failed" => "failed"
      )
      # Verify prefix generates expected methods
      email = build(:email, ai_summary_state: "idle")
      expect(email).to respond_to(:summary_idle?)
      expect(email).to respond_to(:summary_generating?)
    end
  end
end
