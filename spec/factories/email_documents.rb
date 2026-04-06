# == Schema Information
#
# Table name: email_documents
# Database name: primary
#
#  id           :uuid             not null, primary key
#  content_text :text
#  display_name :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  email_id     :uuid             not null
#
# Indexes
#
#  index_email_documents_on_email_id  (email_id)
#
# Foreign Keys
#
#  fk_rails_...  (email_id => emails.id)
#
FactoryBot.define do
  factory :email_document do
    email
    sequence(:display_name) { |n| "Email Document #{n}" }

    after(:build) do |doc|
      doc.file.attach(
        io: StringIO.new("fake file data"),
        filename: "document.pdf",
        content_type: "application/pdf"
      )
    end
  end
end
