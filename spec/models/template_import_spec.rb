require 'rails_helper'

RSpec.describe TemplateImport, type: :model do
  describe "associations" do
    it "belongs to email_template" do
      assoc = described_class.reflect_on_association(:email_template)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "enums" do
    it "defines import_type enum" do
      expect(described_class.import_types).to eq("bundled" => "bundled", "external" => "external")
    end

    it "defines state enum" do
      expect(described_class.states).to eq("pending" => "pending", "processing" => "processing", "completed" => "completed", "failed" => "failed")
    end
  end

  describe "#warnings_list" do
    let(:template_import) { build(:template_import) }

    context "when warnings is blank" do
      before { template_import.warnings = nil }

      it "returns an empty array" do
        expect(template_import.warnings_list).to eq([])
      end
    end

    context "when warnings is valid JSON" do
      before { template_import.warnings = '["missing font","large image"]' }

      it "returns the parsed array" do
        expect(template_import.warnings_list).to eq(["missing font", "large image"])
      end
    end

    context "when warnings is invalid JSON" do
      before { template_import.warnings = "not json at all" }

      it "returns an empty array" do
        expect(template_import.warnings_list).to eq([])
      end
    end
  end
end
