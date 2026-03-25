require 'rails_helper'

RSpec.describe EmailTemplateSection, type: :model do
  describe "associations" do
    it "belongs to email_template" do
      assoc = described_class.reflect_on_association(:email_template)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to parent (optional)" do
      assoc = described_class.reflect_on_association(:parent)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:class_name]).to eq("EmailTemplateSection")
      expect(assoc.options[:optional]).to eq(true)
    end

    it "has many subsections" do
      assoc = described_class.reflect_on_association(:subsections)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:class_name]).to eq("EmailTemplateSection")
      expect(assoc.foreign_key).to eq("parent_id")
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many template_variables" do
      assoc = described_class.reflect_on_association(:template_variables)
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
    it "requires position" do
      section = build(:email_template_section, position: nil)
      expect(section).not_to be_valid
      expect(section.errors[:position]).to include("can't be blank")
    end
  end
end
