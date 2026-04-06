# == Schema Information
#
# Table name: ad_versions
# Database name: primary
#
#  id                :uuid             not null, primary key
#  generated_layers  :jsonb
#  rejection_comment :text
#  state             :enum             default("generating"), not null
#  version_number    :integer          default(1), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  ad_id             :uuid             not null
#  ad_resize_id      :uuid
#  ai_model_id       :uuid             not null
#  ai_service_id     :uuid             not null
#  audience_id       :uuid             not null
#
# Indexes
#
#  idx_ad_versions_on_ad_resize_audience       (ad_id,ad_resize_id,audience_id)
#  idx_ad_versions_unique_per_resize_audience  (ad_id,ad_resize_id,audience_id,version_number) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ad_id => ads.id)
#  fk_rails_...  (ad_resize_id => ad_resizes.id)
#  fk_rails_...  (audience_id => audiences.id)
#
require 'rails_helper'

RSpec.describe AdVersion, type: :model do
  describe "associations" do
    it "belongs to ad" do
      assoc = described_class.reflect_on_association(:ad)
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

    it "belongs to ad_resize (optional)" do
      assoc = described_class.reflect_on_association(:ad_resize)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to eq(true)
    end
  end

  describe "validations" do
    it "requires a version_number" do
      ad_version = build(:ad_version, version_number: nil)
      expect(ad_version).not_to be_valid
      expect(ad_version.errors[:version_number]).to include("can't be blank")
    end
  end

  describe "enums" do
    it "defines state enum" do
      expect(described_class.states).to eq(
        "generating" => "generating", "active" => "active", "rejected" => "rejected"
      )
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active ad versions" do
        active_version = create(:ad_version, state: :active)
        generating_version = create(:ad_version, state: :generating)
        rejected_version = create(:ad_version, state: :rejected)

        expect(described_class.active).to include(active_version)
        expect(described_class.active).not_to include(generating_version, rejected_version)
      end
    end
  end
end
