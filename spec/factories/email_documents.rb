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
