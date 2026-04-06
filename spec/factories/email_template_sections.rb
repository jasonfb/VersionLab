# == Schema Information
#
# Table name: email_template_sections
# Database name: primary
#
#  id                :uuid             not null, primary key
#  element_selector  :string
#  name              :string
#  position          :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  email_template_id :uuid             not null
#  parent_id         :uuid
#
# Indexes
#
#  idx_on_email_template_id_position_c662290fc5  (email_template_id,position)
#
FactoryBot.define do
  factory :email_template_section do
    email_template
    sequence(:name) { |n| "Section #{n}" }
    sequence(:position) { |n| n }
    element_selector { "div.section" }
  end
end
