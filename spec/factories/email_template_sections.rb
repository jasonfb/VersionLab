FactoryBot.define do
  factory :email_template_section do
    email_template
    sequence(:name) { |n| "Section #{n}" }
    sequence(:position) { |n| n }
    element_selector { "div.section" }
  end
end
