require 'rails_helper'

RSpec.describe AiLog, type: :model do
  describe "associations" do
    it "belongs to account" do
      assoc = described_class.reflect_on_association(:account)
      expect(assoc.macro).to eq(:belongs_to)
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

    it "belongs to loggable (polymorphic, optional)" do
      assoc = described_class.reflect_on_association(:loggable)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:polymorphic]).to eq(true)
      expect(assoc.options[:optional]).to eq(true)
    end
  end

  describe "enums" do
    it "defines call_type enum" do
      expect(described_class.call_types).to eq(
        "email" => "email", "campaign_summary" => "campaign_summary",
        "email_summary" => "email_summary", "ad" => "ad"
      )
    end
  end
end
