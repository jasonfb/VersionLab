# == Schema Information
#
# Table name: ad_resizes
# Database name: primary
#
#  id              :uuid             not null, primary key
#  aspect_ratio    :string
#  height          :integer          not null
#  layer_overrides :jsonb
#  platform_labels :jsonb            not null
#  resized_layers  :jsonb
#  state           :enum             default("pending"), not null
#  width           :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  ad_id           :uuid             not null
#
# Indexes
#
#  index_ad_resizes_on_ad_id                       (ad_id)
#  index_ad_resizes_on_ad_id_and_width_and_height  (ad_id,width,height) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ad_id => ads.id)
#
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
