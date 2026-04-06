# == Schema Information
#
# Table name: roles
# Database name: primary
#
#  id         :uuid             not null, primary key
#  label      :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :role do
    name { "MyString" }
    label { "MyString" }
  end
end
