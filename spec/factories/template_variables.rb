FactoryBot.define do
  factory :template_variable do
    email_template_section
    sequence(:name) { |n| "Variable #{n}" }
    variable_type { "text" }
    default_value { "Default text" }
    sequence(:position) { |n| n }
  end
end
