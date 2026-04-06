# == Schema Information
#
# Table name: client_users
# Database name: primary
#
#  id         :uuid             not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  client_id  :uuid             not null
#  user_id    :uuid             not null
#
# Indexes
#
#  index_client_users_on_client_id_and_user_id  (client_id,user_id) UNIQUE
#
require 'rails_helper'

RSpec.describe ClientUser, type: :model do
  describe "associations" do
    it "belongs to client" do
      assoc = described_class.reflect_on_association(:client)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to user" do
      assoc = described_class.reflect_on_association(:user)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end
end
