class EmailSectionAutolinkSetting < ApplicationRecord
  belongs_to :email
  belongs_to :email_template_section

  enum :autolink_mode, { none: "none", link_relevant_text: "link_relevant_text" }, prefix: :autolink
  enum :link_mode, { user_url: "user_url", ai_decide: "ai_decide" }, allow_nil: true
end
