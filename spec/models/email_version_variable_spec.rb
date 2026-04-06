# == Schema Information
#
# Table name: email_version_variables
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  value                :text             not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  email_version_id     :uuid             not null
#  template_variable_id :uuid             not null
#
# Indexes
#
#  idx_merge_version_variables_unique  (email_version_id,template_variable_id) UNIQUE
#
require 'rails_helper'

RSpec.describe EmailVersionVariable, type: :model do
  describe "associations" do
    it "belongs to email_version" do
      assoc = described_class.reflect_on_association(:email_version)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to template_variable" do
      assoc = described_class.reflect_on_association(:template_variable)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires value" do
      evv = build(:email_version_variable, value: nil)
      expect(evv).not_to be_valid
      expect(evv.errors[:value]).to include("can't be blank")
    end

    it "requires template_variable_id to be unique per email_version" do
      existing = create(:email_version_variable)
      duplicate = build(:email_version_variable,
        email_version: existing.email_version,
        template_variable: existing.template_variable)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:template_variable_id]).to include("has already been taken")
    end
  end
end
