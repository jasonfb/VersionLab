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
class EmailTemplateSection < ApplicationRecord
  belongs_to :email_template
  belongs_to :parent, class_name: 'EmailTemplateSection', optional: true
  has_many :subsections, class_name: 'EmailTemplateSection', foreign_key: :parent_id, dependent: :destroy
  has_many :template_variables, dependent: :destroy
  has_many :email_section_autolink_settings, dependent: :destroy

  validates :position, presence: true
end
