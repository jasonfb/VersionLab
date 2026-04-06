# == Schema Information
#
# Table name: template_imports
# Database name: primary
#
#  id                :uuid             not null, primary key
#  error_message     :text
#  import_type       :enum             not null
#  state             :enum             default("pending"), not null
#  warnings          :text
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  email_template_id :uuid             not null
#
# Indexes
#
#  index_template_imports_on_email_template_id  (email_template_id)
#
# Foreign Keys
#
#  fk_rails_...  (email_template_id => email_templates.id)
#
class TemplateImport < ApplicationRecord
  belongs_to :email_template
  has_one_attached :source_file

  enum :import_type, { bundled: "bundled", external: "external" }
  enum :state, { pending: "pending", processing: "processing", completed: "completed", failed: "failed" }

  def warnings_list
    return [] if warnings.blank?
    JSON.parse(warnings)
  rescue JSON::ParserError
    []
  end
end
