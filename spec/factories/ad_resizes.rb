FactoryBot.define do
  factory :ad_resize do
    ad
    platform_labels { [ { "platform" => "Facebook (Meta)", "size_name" => "Feed Image" } ] }
    width { 1080 }
    height { 1080 }
    aspect_ratio { "1:1" }
    state { "pending" }
  end
end
