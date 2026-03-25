require 'rails_helper'

RSpec.describe EmailSectionAutolinkSetting, type: :model do
  describe "associations" do
    it "belongs to email" do
      assoc = described_class.reflect_on_association(:email)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to email_template_section" do
      assoc = described_class.reflect_on_association(:email_template_section)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "enums" do
    it "defines autolink_mode enum with autolink prefix" do
      expect(described_class.autolink_modes).to eq(
        "none" => "none",
        "link_relevant_text" => "link_relevant_text"
      )
      setting = build(:email_section_autolink_setting)
      expect(setting).to respond_to(:autolink_none?)
      expect(setting).to respond_to(:autolink_link_relevant_text?)
    end

    it "defines link_mode enum" do
      expect(described_class.link_modes).to eq(
        "user_url" => "user_url",
        "ai_decide" => "ai_decide"
      )
    end
  end
end
