# == Schema Information
#
# Table name: roles
# Database name: primary
#
#  id         :uuid             not null, primary key
#  label      :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require 'rails_helper'

RSpec.describe Role, type: :model do
  describe "associations" do
    it "has many user_roles" do
      assoc = described_class.reflect_on_association(:user_roles)
      expect(assoc.macro).to eq(:has_many)
    end

    it "has many users through user_roles" do
      assoc = described_class.reflect_on_association(:users)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:user_roles)
    end
  end
end
