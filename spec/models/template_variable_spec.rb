require 'rails_helper'

RSpec.describe TemplateVariable, type: :model do
  describe "associations" do
    it "belongs to email_template_section" do
      assoc = described_class.reflect_on_association(:email_template_section)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires name" do
      var = build(:template_variable, name: nil)
      expect(var).not_to be_valid
      expect(var.errors[:name]).to include("can't be blank")
    end

    it "requires name to be unique per section" do
      existing = create(:template_variable, name: "headline")
      duplicate = build(:template_variable, name: "headline", email_template_section: existing.email_template_section)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end

    it "requires variable_type" do
      var = build(:template_variable, variable_type: nil)
      expect(var).not_to be_valid
      expect(var.errors[:variable_type]).to be_present
    end

    it "validates variable_type inclusion in text and image" do
      var = build(:template_variable, variable_type: "video")
      expect(var).not_to be_valid
      expect(var.errors[:variable_type]).to include("is not included in the list")
    end

    it "accepts text as variable_type" do
      var = build(:template_variable, variable_type: "text")
      var.valid?
      expect(var.errors[:variable_type]).to be_empty
    end

    it "accepts image as variable_type" do
      var = build(:template_variable, variable_type: "image")
      var.valid?
      expect(var.errors[:variable_type]).to be_empty
    end

    it "requires default_value" do
      var = build(:template_variable, default_value: nil)
      expect(var).not_to be_valid
      expect(var.errors[:default_value]).to include("can't be blank")
    end

    it "requires position" do
      var = build(:template_variable, position: nil)
      expect(var).not_to be_valid
      expect(var.errors[:position]).to include("can't be blank")
    end

    it "validates slot_role inclusion when present" do
      var = build(:template_variable, slot_role: "invalid_role")
      expect(var).not_to be_valid
      expect(var.errors[:slot_role]).to include("is not included in the list")
    end

    it "allows nil slot_role" do
      var = build(:template_variable, slot_role: nil)
      var.valid?
      expect(var.errors[:slot_role]).to be_empty
    end

    it "accepts valid slot_roles" do
      TemplateVariable::SLOT_ROLES.each do |role|
        var = build(:template_variable, slot_role: role)
        var.valid?
        expect(var.errors[:slot_role]).to be_empty, "Expected #{role} to be valid"
      end
    end
  end

  describe "SLOT_ROLES" do
    it "contains the expected roles" do
      expect(TemplateVariable::SLOT_ROLES).to eq(%w[teaser_text eyebrow headline subheadline body cta_text image])
    end
  end
end
