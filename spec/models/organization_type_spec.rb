# == Schema Information
#
# Table name: organization_types
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require 'rails_helper'

RSpec.describe OrganizationType, type: :model do
  describe "associations" do
    it "has many brand_profiles" do
      assoc = described_class.reflect_on_association(:brand_profiles)
      expect(assoc.macro).to eq(:has_many)
    end
  end

  describe "validations" do
    it "requires a name" do
      org_type = build(:organization_type, name: nil)
      expect(org_type).not_to be_valid
      expect(org_type.errors[:name]).to include("can't be blank")
    end
  end

  describe "default_scope" do
    it "orders by position" do
      second = create(:organization_type, position: 2)
      first = create(:organization_type, position: 1)
      third = create(:organization_type, position: 3)

      expect(described_class.all.to_a).to eq([first, second, third])
    end
  end
end
