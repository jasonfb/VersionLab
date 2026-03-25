FactoryBot.define do
  factory :campaign_document do
    campaign
    sequence(:display_name) { |n| "Document #{n}" }

    after(:build) do |doc|
      doc.file.attach(
        io: StringIO.new("fake file data"),
        filename: "document.pdf",
        content_type: "application/pdf"
      )
    end
  end
end
