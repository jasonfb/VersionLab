FactoryBot.define do
  factory :email_template do
    client
    name { "Test Template" }
    raw_source_html { "<html><body>Hello</body></html>" }
  end
end
