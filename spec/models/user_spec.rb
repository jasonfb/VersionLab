# == Schema Information
#
# Table name: users
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  name                   :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
require 'rails_helper'

RSpec.describe User, type: :model do
  describe "associations" do
    it "has many user_roles" do
      assoc = described_class.reflect_on_association(:user_roles)
      expect(assoc.macro).to eq(:has_many)
    end

    it "has many roles through user_roles" do
      assoc = described_class.reflect_on_association(:roles)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:user_roles)
    end

    it "has many account_users" do
      assoc = described_class.reflect_on_association(:account_users)
      expect(assoc.macro).to eq(:has_many)
    end

    it "has many accounts through account_users" do
      assoc = described_class.reflect_on_association(:accounts)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:account_users)
    end

    it "has many client_users with dependent destroy" do
      assoc = described_class.reflect_on_association(:client_users)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many clients through client_users" do
      assoc = described_class.reflect_on_association(:clients)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:client_users)
    end
  end

  describe "#admin?" do
    let(:user) { create(:user) }

    context "when user has an admin role" do
      before do
        admin_role = create(:role, name: "admin")
        create(:user_role, user: user, role: admin_role)
      end

      it "returns true" do
        expect(user.admin?).to be true
      end
    end

    context "when user does not have an admin role" do
      it "returns false" do
        expect(user.admin?).to be false
      end
    end

    context "when user has a non-admin role" do
      before do
        other_role = create(:role, name: "editor")
        create(:user_role, user: user, role: other_role)
      end

      it "returns false" do
        expect(user.admin?).to be false
      end
    end
  end
end
