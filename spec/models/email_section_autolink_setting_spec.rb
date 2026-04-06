# == Schema Information
#
# Table name: email_section_autolink_settings
# Database name: primary
#
#  id                          :uuid             not null, primary key
#  autolink_mode               :enum             default("none"), not null
#  bold_links                  :boolean          default(FALSE), not null
#  group_purpose               :text
#  italic_links                :boolean          default(FALSE), not null
#  link_color                  :string
#  link_mode                   :enum
#  override_brand_link_styling :boolean          default(FALSE), not null
#  underline_links             :boolean          default(FALSE), not null
#  url                         :string
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  email_id                    :uuid             not null
#  email_template_section_id   :uuid             not null
#
# Indexes
#
#  idx_on_email_id_email_template_section_id_74badd651c  (email_id,email_template_section_id) UNIQUE
#
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
