require 'rails_helper'

RSpec.describe AiModel, type: :model do
  describe "associations" do
    it "belongs to ai_service" do
      assoc = described_class.reflect_on_association(:ai_service)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires a name" do
      model = build(:ai_model, name: nil)
      expect(model).not_to be_valid
      expect(model.errors[:name]).to include("can't be blank")
    end

    it "requires an api_identifier" do
      model = build(:ai_model, api_identifier: nil)
      expect(model).not_to be_valid
      expect(model.errors[:api_identifier]).to include("can't be blank")
    end
  end

  describe "scopes" do
    let(:ai_service) { create(:ai_service) }
    let!(:text_model) { create(:ai_model, ai_service: ai_service, for_text: true, for_image: false) }
    let!(:image_model) { create(:ai_model, ai_service: ai_service, for_text: false, for_image: true) }
    let!(:both_model) { create(:ai_model, ai_service: ai_service, for_text: true, for_image: true) }

    describe ".for_text" do
      it "returns models where for_text is true" do
        expect(described_class.for_text).to include(text_model, both_model)
        expect(described_class.for_text).not_to include(image_model)
      end
    end

    describe ".for_image" do
      it "returns models where for_image is true" do
        expect(described_class.for_image).to include(image_model, both_model)
        expect(described_class.for_image).not_to include(text_model)
      end
    end
  end
end
