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
class EmailDocument < ApplicationRecord
  belongs_to :email
  has_one_attached :file

  validates :display_name, presence: true

  after_commit :trigger_summary, on: [ :create, :destroy ]

  private

  def trigger_summary
    EmailSummaryJob.perform_later(email_id)
  end
end
