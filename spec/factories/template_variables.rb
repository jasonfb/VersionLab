# == Schema Information
#
# Table name: template_variables
# Database name: primary
#
#  id                        :uuid             not null, primary key
#  default_value             :text             not null
#  image_location            :enum
#  name                      :string           not null
#  position                  :integer          not null
#  slot_role                 :enum
#  variable_type             :string           default("text"), not null
#  word_count                :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  email_template_section_id :uuid             not null
#
# Indexes
#
#  idx_on_email_template_section_id_position_ec7798dbd9  (email_template_section_id,position)
#
FactoryBot.define do
  factory :template_variable do
    email_template_section
    sequence(:name) { |n| "Variable #{n}" }
    variable_type { "text" }
    default_value { "Default text" }
    sequence(:position) { |n| n }
  end
end
