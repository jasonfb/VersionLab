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
