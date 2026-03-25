require 'rails_helper'

RSpec.describe AiKey, type: :model do
  describe "associations" do
    it "belongs to account" do
      assoc = described_class.reflect_on_association(:account)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to ai_service" do
      assoc = described_class.reflect_on_association(:ai_service)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires an api_key" do
      key = build(:ai_key, api_key: nil)
      expect(key).not_to be_valid
      expect(key.errors[:api_key]).to include("can't be blank")
    end

    it "requires ai_service_id to be unique per account" do
      existing = create(:ai_key)
      duplicate = build(:ai_key, account: existing.account, ai_service: existing.ai_service)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:ai_service_id]).to include("has already been taken")
    end
  end
end
