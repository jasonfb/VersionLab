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
class TemplateVariable < ApplicationRecord
  SLOT_ROLES = %w[teaser_text eyebrow headline subheadline body cta_text image].freeze

  belongs_to :email_template_section

  validates :name, presence: true, uniqueness: { scope: :email_template_section_id }
  validates :variable_type, presence: true, inclusion: { in: %w[text image] }
  validates :default_value, presence: true
  validates :position, presence: true
  validates :slot_role, inclusion: { in: SLOT_ROLES }, allow_nil: true
end
