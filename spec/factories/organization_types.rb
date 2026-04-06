# == Schema Information
#
# Table name: organization_types
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :organization_type do
    sequence(:name) { |n| "Organization Type #{n}" }
    sequence(:position) { |n| n }
  end
end
