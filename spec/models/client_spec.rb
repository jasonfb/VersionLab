require 'rails_helper'

RSpec.describe Client, type: :model do
  describe "associations" do
    it "belongs to account" do
      assoc = described_class.reflect_on_association(:account)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "has many ads with dependent destroy" do
      assoc = described_class.reflect_on_association(:ads)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many email_templates with dependent destroy" do
      assoc = described_class.reflect_on_association(:email_templates)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many emails with dependent destroy" do
      assoc = described_class.reflect_on_association(:emails)
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

    it "has many campaigns with dependent destroy" do
      assoc = described_class.reflect_on_association(:campaigns)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has one brand_profile with dependent destroy" do
      assoc = described_class.reflect_on_association(:brand_profile)
      expect(assoc.macro).to eq(:has_one)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many client_users with dependent destroy" do
      assoc = described_class.reflect_on_association(:client_users)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many users through client_users" do
      assoc = described_class.reflect_on_association(:users)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:client_users)
    end
  end

  describe "validations" do
    it "requires a name" do
      client = build(:client, name: nil)
      expect(client).not_to be_valid
      expect(client.errors[:name]).to include("can't be blank")
    end

    it "is valid with a name" do
      client = build(:client)
      expect(client).to be_valid
    end
  end

  describe "scopes" do
    let(:account) { create(:account) }
    let!(:visible_client) { create(:client, account: account, hidden: false) }
    let!(:hidden_client) { create(:client, account: account, hidden: true) }

    describe ".visible" do
      it "returns only clients where hidden is false" do
        expect(described_class.visible).to include(visible_client)
        expect(described_class.visible).not_to include(hidden_client)
      end
    end

    describe ".hidden_clients" do
      it "returns only clients where hidden is true" do
        expect(described_class.hidden_clients).to include(hidden_client)
        expect(described_class.hidden_clients).not_to include(visible_client)
      end
    end
  end
end
