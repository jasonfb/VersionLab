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
class EmailSectionAutolinkSetting < ApplicationRecord
  belongs_to :email
  belongs_to :email_template_section

  enum :autolink_mode, { none: "none", link_relevant_text: "link_relevant_text" }, prefix: :autolink
  enum :link_mode, { user_url: "user_url", ai_decide: "ai_decide" }, allow_nil: true
end
