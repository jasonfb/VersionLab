class TemplateVariable < ApplicationRecord
  belongs_to :email_template_section

  validates :name, presence: true, uniqueness: { scope: :email_template_section_id }
  validates :variable_type, presence: true, inclusion: { in: %w[text image] }
  validates :default_value, presence: true
  validates :position, presence: true
end
