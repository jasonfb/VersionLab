class EmailVersionVariable < ApplicationRecord
  belongs_to :email_version
  belongs_to :template_variable

  validates :value, presence: true
  validates :template_variable_id, uniqueness: { scope: :email_version_id }
end
