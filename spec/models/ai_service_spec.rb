require 'rails_helper'

RSpec.describe AiService, type: :model do
  describe "associations" do
    it "has many ai_models with dependent destroy" do
      assoc = described_class.reflect_on_association(:ai_models)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many ai_keys with dependent destroy" do
      assoc = described_class.reflect_on_association(:ai_keys)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end
  end

  describe "validations" do
    it "requires a name" do
      service = build(:ai_service, name: nil)
      expect(service).not_to be_valid
      expect(service.errors[:name]).to include("can't be blank")
    end

    it "requires a unique name" do
      create(:ai_service, name: "OpenAI")
      duplicate = build(:ai_service, name: "OpenAI")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end

    it "requires a slug" do
      service = build(:ai_service, slug: nil)
      expect(service).not_to be_valid
      expect(service.errors[:slug]).to include("can't be blank")
    end

    it "requires a unique slug" do
      create(:ai_service, slug: "openai")
      duplicate = build(:ai_service, slug: "openai")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to include("has already been taken")
    end
  end
end
