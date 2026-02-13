class EmailTemplateSection < ApplicationRecord
  belongs_to :email_template
  has_many :template_variables, dependent: :destroy

  validates :position, presence: true
end
