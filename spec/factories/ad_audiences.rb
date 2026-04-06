# == Schema Information
#
# Table name: ad_audiences
# Database name: primary
#
#  id          :uuid             not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  ad_id       :uuid             not null
#  audience_id :uuid             not null
#
# Indexes
#
#  index_ad_audiences_on_ad_id_and_audience_id  (ad_id,audience_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ad_id => ads.id)
#  fk_rails_...  (audience_id => audiences.id)
#
FactoryBot.define do
  factory :ad_audience do
    ad
    audience
  end
end
