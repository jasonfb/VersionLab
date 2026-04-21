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
require 'rails_helper'

RSpec.describe EmailDocument, type: :model do
  before do
    allow(EmailSummaryJob).to receive(:perform_later)
  end

  describe "associations" do
    it "belongs to email" do
      assoc = described_class.reflect_on_association(:email)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires display_name" do
      doc = build(:email_document, display_name: nil)
      expect(doc).not_to be_valid
      expect(doc.errors[:display_name]).to include("can't be blank")
    end
  end

  describe "after_commit :trigger_summary" do
    it "enqueues EmailSummaryJob on create" do
      doc = create(:email_document)
      expect(EmailSummaryJob).to have_received(:perform_later).with(doc.email_id)
    end

    it "enqueues EmailSummaryJob on destroy" do
      doc = create(:email_document)
      email_id = doc.email_id
      # Reset expectations after create so we only track destroy
      RSpec::Mocks.space.proxy_for(EmailSummaryJob).reset
      allow(EmailSummaryJob).to receive(:perform_later)
      doc.destroy!
      expect(EmailSummaryJob).to have_received(:perform_later).with(email_id)
    end
  end
end
