class Campaign < ApplicationRecord
  belongs_to :client
  has_many :campaign_documents, dependent: :destroy
  has_many :campaign_links, dependent: :destroy

  validates :name, presence: true

  enum :status, { draft: "draft", active: "active", completed: "completed", archived: "archived" }
  enum :ai_summary_state, { idle: "idle", generating: "generating", generated: "generated", failed: "failed" }
end
