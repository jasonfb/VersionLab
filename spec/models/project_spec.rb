require 'rails_helper'

RSpec.describe Project, type: :model do
  describe "associations" do
    it "belongs to account" do
      assoc = described_class.reflect_on_association(:account)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "has many email_templates with dependent destroy" do
      assoc = described_class.reflect_on_association(:email_templates)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many audiences with dependent destroy" do
      assoc = described_class.reflect_on_association(:audiences)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many assets with dependent destroy" do
      assoc = described_class.reflect_on_association(:assets)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end
  end

  describe "validations" do
    it "has a presence validation on name" do
      validators = described_class.validators_on(:name)
      presence = validators.find { |v| v.is_a?(ActiveRecord::Validations::PresenceValidator) }
      expect(presence).not_to be_nil
    end
  end

  describe "scopes" do
    it "defines a visible scope" do
      expect(described_class).to respond_to(:visible)
    end

    it "defines a hidden_projects scope" do
      expect(described_class).to respond_to(:hidden_projects)
    end
  end
end
