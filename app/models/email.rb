# == Schema Information
#
# Table name: emails
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  ai_summary              :text
#  ai_summary_generated_at :datetime
#  ai_summary_state        :enum             default("idle"), not null
#  context                 :text
#  state                   :enum             default("setup"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  ai_model_id             :uuid
#  ai_service_id           :uuid
#  campaign_id             :uuid
#  client_id               :uuid             not null
#  email_template_id       :uuid             not null
#
# Indexes
#
#  index_emails_on_campaign_id  (campaign_id)
#  index_emails_on_client_id    (client_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#  fk_rails_...  (client_id => clients.id)
#
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
