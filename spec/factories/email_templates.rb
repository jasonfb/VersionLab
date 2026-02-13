FactoryBot.define do
  factory :email_template do
    account_id { "" }
    name { "MyString" }
    raw_source_html { "MyText" }
  end
end
