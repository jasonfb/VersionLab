# == Schema Information
#
# Table name: tone_rules
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :tone_rule do
    sequence(:name) { |n| "Tone Rule #{n}" }
    sequence(:position) { |n| n }
  end
end
