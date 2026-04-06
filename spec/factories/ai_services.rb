# == Schema Information
#
# Table name: ai_services
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_ai_services_on_slug  (slug) UNIQUE
#
FactoryBot.define do
  factory :ai_service do
    sequence(:name) { |n| "AI Service #{n}" }
    sequence(:slug) { |n| "ai-service-#{n}" }
  end
end
