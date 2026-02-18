class MergeVersionVariable < ApplicationRecord
  belongs_to :merge_version
  belongs_to :template_variable

  validates :value, presence: true
  validates :template_variable_id, uniqueness: { scope: :merge_version_id }
end
