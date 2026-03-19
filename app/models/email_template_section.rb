class EmailTemplateSection < ApplicationRecord
  belongs_to :email_template
  belongs_to :parent, class_name: 'EmailTemplateSection', optional: true
  has_many :subsections, class_name: 'EmailTemplateSection', foreign_key: :parent_id, dependent: :destroy
  has_many :template_variables, dependent: :destroy

  validates :position, presence: true
end
