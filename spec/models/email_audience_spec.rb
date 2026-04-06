# == Schema Information
#
# Table name: email_audiences
# Database name: primary
#
#  id          :uuid             not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  audience_id :uuid             not null
#  email_id    :uuid             not null
#
require 'rails_helper'

RSpec.describe EmailAudience, type: :model do
  describe "associations" do
    it "belongs to email" do
      assoc = described_class.reflect_on_association(:email)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to audience" do
      assoc = described_class.reflect_on_association(:audience)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end
end
