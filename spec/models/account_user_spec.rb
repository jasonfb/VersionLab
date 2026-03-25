require 'rails_helper'

RSpec.describe AccountUser, type: :model do
  describe "associations" do
    it "belongs to account" do
      assoc = described_class.reflect_on_association(:account)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to user" do
      assoc = described_class.reflect_on_association(:user)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "#role_label" do
    let(:account_user) { build(:account_user) }

    context "when is_owner is true" do
      before { account_user.is_owner = true }

      it "returns 'Owner'" do
        expect(account_user.role_label).to eq("Owner")
      end

      it "returns 'Owner' even when other flags are also true" do
        account_user.is_admin = true
        account_user.is_billing_admin = true
        expect(account_user.role_label).to eq("Owner")
      end
    end

    context "when is_admin is true" do
      before { account_user.is_admin = true }

      it "returns 'Admin'" do
        expect(account_user.role_label).to eq("Admin")
      end

      it "returns 'Admin' even when is_billing_admin is also true" do
        account_user.is_billing_admin = true
        expect(account_user.role_label).to eq("Admin")
      end
    end

    context "when is_billing_admin is true" do
      before { account_user.is_billing_admin = true }

      it "returns 'Billing Admin'" do
        expect(account_user.role_label).to eq("Billing Admin")
      end
    end

    context "when no flags are set" do
      it "returns 'Member'" do
        expect(account_user.role_label).to eq("Member")
      end
    end
  end
end
