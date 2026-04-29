FactoryBot.define do
  factory :ad_shape_layout_rule do
    ad_shape
    role { "headline" }
    anchor_x { 0.05 }
    anchor_y { 0.16 }
    anchor_w { 0.90 }
    anchor_h { 0.25 }
    font_scale { 1.0 }
    align { "center" }
    drop { false }
    sequence(:position) { |n| n }
  end
end
