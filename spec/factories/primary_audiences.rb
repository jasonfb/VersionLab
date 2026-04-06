# == Schema Information
#
# Table name: primary_audiences
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :primary_audience do
    sequence(:name) { |n| "Primary Audience #{n}" }
    sequence(:position) { |n| n }
  end
end
