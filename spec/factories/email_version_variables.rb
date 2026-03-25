FactoryBot.define do
  factory :email_version_variable do
    email_version
    template_variable
    value { "Generated value" }
  end
end
