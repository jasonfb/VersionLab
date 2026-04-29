FactoryBot.define do
  factory :ad_platform_size do
    ad_platform
    sequence(:name) { |n| "Size #{n}" }
    width { 1080 }
    height { 1080 }
    sequence(:position) { |n| n }
  end
end
