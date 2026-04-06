# == Schema Information
#
# Table name: ai_logs
# Database name: primary
#
#  id                :uuid             not null, primary key
#  _cost_to_us_cents :integer
#  call_type         :enum             not null
#  completion_tokens :integer
#  loggable_type     :string
#  prompt            :text
#  prompt_tokens     :integer
#  response          :text
#  total_tokens      :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :uuid             not null
#  ai_model_id       :uuid
#  ai_service_id     :uuid
#  loggable_id       :uuid
#
# Indexes
#
#  idx_ai_logs_on_loggable      (loggable_type,loggable_id)
#  index_ai_logs_on_account_id  (account_id)
#  index_ai_logs_on_created_at  (created_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
require 'rails_helper'

RSpec.describe AiLog, type: :model do
  describe "associations" do
    it "belongs to account" do
      assoc = described_class.reflect_on_association(:account)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to ai_service (optional)" do
      assoc = described_class.reflect_on_association(:ai_service)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to eq(true)
    end

    it "belongs to ai_model (optional)" do
      assoc = described_class.reflect_on_association(:ai_model)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to eq(true)
    end

    it "belongs to loggable (polymorphic, optional)" do
      assoc = described_class.reflect_on_association(:loggable)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:polymorphic]).to eq(true)
      expect(assoc.options[:optional]).to eq(true)
    end
  end

  describe "enums" do
    it "defines call_type enum" do
      expect(described_class.call_types).to eq(
        "email" => "email", "campaign_summary" => "campaign_summary",
        "email_summary" => "email_summary", "ad" => "ad"
      )
    end
  end
end
