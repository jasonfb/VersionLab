class Email < ApplicationRecord
  belongs_to :client
  belongs_to :email_template
  belongs_to :campaign, optional: true
  belongs_to :ai_service, optional: true
  belongs_to :ai_model, optional: true
  has_many :email_audiences, dependent: :destroy
  has_many :audiences, through: :email_audiences
  has_many :email_versions, dependent: :destroy
  has_many :email_documents, dependent: :destroy
  has_many :email_section_autolink_settings, dependent: :destroy

  validates :context, length: { maximum: 5000 }, allow_blank: true

  enum :state, { setup: "setup", pending: "pending", merged: "merged", regenerating: "regenerating" }
  enum :ai_summary_state, { idle: "idle", generating: "generating", generated: "generated", failed: "failed" }, prefix: :summary
end
