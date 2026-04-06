# == Schema Information
#
# Table name: campaign_documents
# Database name: primary
#
#  id           :uuid             not null, primary key
#  content_text :text
#  display_name :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  campaign_id  :uuid             not null
#
# Indexes
#
#  index_campaign_documents_on_campaign_id  (campaign_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#
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
