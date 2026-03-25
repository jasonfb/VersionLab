FactoryBot.define do
  factory :template_import do
    email_template
    import_type { "bundled" }
    state { "pending" }
  end
end
