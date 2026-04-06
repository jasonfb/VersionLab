# == Schema Information
#
# Table name: email_versions
# Database name: primary
#
#  id                :uuid             not null, primary key
#  rejection_comment :text
#  state             :enum             default("generating"), not null
#  version_number    :integer          default(1), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  ai_model_id       :uuid             not null
#  ai_service_id     :uuid             not null
#  audience_id       :uuid             not null
#  email_id          :uuid             not null
#
# Indexes
#
#  idx_merge_versions_on_merge_and_audience  (email_id,audience_id)
#  idx_merge_versions_unique                 (email_id,audience_id,version_number) UNIQUE
#
require 'rails_helper'

RSpec.describe EmailVersion, type: :model do
  describe "associations" do
    it "belongs to email" do
      assoc = described_class.reflect_on_association(:email)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to audience" do
      assoc = described_class.reflect_on_association(:audience)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to ai_service" do
      assoc = described_class.reflect_on_association(:ai_service)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to ai_model" do
      assoc = described_class.reflect_on_association(:ai_model)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "has many email_version_variables" do
      assoc = described_class.reflect_on_association(:email_version_variables)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end
  end

  describe "validations" do
    it "requires version_number" do
      version = build(:email_version, version_number: nil)
      expect(version).not_to be_valid
      expect(version.errors[:version_number]).to include("can't be blank")
    end
  end

  describe "enums" do
    it "defines state enum" do
      expect(described_class.states).to eq(
        "generating" => "generating",
        "active" => "active",
        "rejected" => "rejected"
      )
    end
  end
end
