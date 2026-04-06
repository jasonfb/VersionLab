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
require 'rails_helper'

RSpec.describe CampaignLink, type: :model do
  describe "associations" do
    it "belongs to campaign" do
      assoc = described_class.reflect_on_association(:campaign)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires a url" do
      link = build(:campaign_link, url: nil)
      expect(link).not_to be_valid
      expect(link.errors[:url]).to include("can't be blank")
    end
  end
end
