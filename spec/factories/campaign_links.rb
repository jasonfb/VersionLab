# == Schema Information
#
# Table name: campaign_links
# Database name: primary
#
#  id               :uuid             not null, primary key
#  fetched_at       :datetime
#  image_url        :text
#  link_description :text
#  title            :string
#  url              :text             not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  campaign_id      :uuid             not null
#
# Indexes
#
#  index_campaign_links_on_campaign_id  (campaign_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#
FactoryBot.define do
  factory :campaign_link do
    campaign
    sequence(:url) { |n| "https://example.com/link-#{n}" }
  end
end
