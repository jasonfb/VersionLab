require 'rails_helper'

RSpec.describe Account, type: :model do
  describe "associations" do
    it "has many clients" do
      assoc = described_class.reflect_on_association(:clients)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many account_users" do
      assoc = described_class.reflect_on_association(:account_users)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many users through account_users" do
      assoc = described_class.reflect_on_association(:users)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:account_users)
    end

    it "has many ai_keys" do
      assoc = described_class.reflect_on_association(:ai_keys)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many ai_logs" do
      assoc = described_class.reflect_on_association(:ai_logs)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end
  end

  describe "#default_client" do
    let(:account) { create(:account) }

    context "when a hidden client exists" do
      let!(:hidden_client) { create(:client, account: account, hidden: true) }
      let!(:visible_client) { create(:client, account: account, hidden: false) }

      it "returns the hidden client" do
        expect(account.default_client).to eq(hidden_client)
      end
    end

    context "when no hidden client exists" do
      let!(:visible_client) { create(:client, account: account, hidden: false) }

      it "returns nil" do
        expect(account.default_client).to be_nil
      end
    end
  end
end
