# == Schema Information
#
# Table name: email_templates
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  name                     :string
#  original_raw_source_html :text
#  raw_source_html          :text
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  client_id                :uuid             not null
#
FactoryBot.define do
  factory :email_template do
    client
    name { "Test Template" }
    raw_source_html { "<html><body>Hello</body></html>" }
  end
end
