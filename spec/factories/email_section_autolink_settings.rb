FactoryBot.define do
  factory :email_section_autolink_setting do
    email
    email_template_section
    autolink_mode { "none" }
    link_mode { nil }
  end
end
