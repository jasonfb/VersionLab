require 'rails_helper'

RSpec.describe Audience, type: :model do
  describe "associations" do
    it "belongs to client" do
      assoc = described_class.reflect_on_association(:client)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires a name" do
      audience = build(:audience, name: nil)
      expect(audience).not_to be_valid
      expect(audience.errors[:name]).to include("can't be blank")
    end
  end
end
