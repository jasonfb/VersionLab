# == Schema Information
#
# Table name: user_roles
# Database name: primary
#
#  id         :uuid             not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  role_id    :uuid
#  user_id    :uuid
#
require 'rails_helper'

RSpec.describe UserRole, type: :model do
  describe "associations" do
    it "belongs to user" do
      assoc = described_class.reflect_on_association(:user)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to role" do
      assoc = described_class.reflect_on_association(:role)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end
end
