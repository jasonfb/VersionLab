# == Schema Information
#
# Table name: industries
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :industry do
    sequence(:name) { |n| "Industry #{n}" }
    sequence(:position) { |n| n }
  end
end
