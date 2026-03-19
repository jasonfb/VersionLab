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
