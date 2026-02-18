class Merge < ApplicationRecord
  belongs_to :email_template
  belongs_to :ai_service, optional: true
  belongs_to :ai_model, optional: true
  has_many :merge_audiences, dependent: :destroy
  has_many :audiences, through: :merge_audiences
  has_many :merge_versions, dependent: :destroy

  enum :state, { setup: "setup", pending: "pending", merged: "merged", regenerating: "regenerating" }

  delegate :project, to: :email_template
end
