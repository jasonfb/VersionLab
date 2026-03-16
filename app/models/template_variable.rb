class TemplateVariable < ApplicationRecord
  SLOT_ROLES = %w[teaser_text eyebrow headline subheadline body cta_text image].freeze

  belongs_to :email_template_section

  validates :name, presence: true, uniqueness: { scope: :email_template_section_id }
  validates :variable_type, presence: true, inclusion: { in: %w[text image] }
  validates :default_value, presence: true
  validates :position, presence: true
  validates :slot_role, inclusion: { in: SLOT_ROLES }, allow_nil: true
end
