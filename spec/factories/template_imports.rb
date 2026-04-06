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
FactoryBot.define do
  factory :template_import do
    email_template
    import_type { "bundled" }
    state { "pending" }
  end
end
