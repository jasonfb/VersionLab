# == Schema Information
#
# Table name: geographies
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :geography do
    sequence(:name) { |n| "Geography #{n}" }
    sequence(:position) { |n| n }
  end
end
