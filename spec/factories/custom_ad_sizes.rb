FactoryBot.define do
  factory :custom_ad_size do
    client
    label { "Custom Banner" }
    width { 800 }
    height { 200 }
  end
end
