# == Schema Information
#
# Table name: ai_models
# Database name: primary
#
#  id                         :uuid             not null, primary key
#  api_identifier             :string           not null
#  for_image                  :boolean          default(FALSE), not null
#  for_text                   :boolean          default(FALSE), not null
#  input_cost_per_mtok_cents  :integer
#  name                       :string           not null
#  output_cost_per_mtok_cents :integer
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  ai_service_id              :uuid             not null
#
# Indexes
#
#  index_ai_models_on_ai_service_id  (ai_service_id)
#
FactoryBot.define do
  factory :ai_model do
    ai_service
    sequence(:name) { |n| "AI Model #{n}" }
    sequence(:api_identifier) { |n| "model-#{n}" }
    for_text { true }
    for_image { false }
  end
end
