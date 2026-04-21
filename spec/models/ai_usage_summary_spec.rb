require 'rails_helper'

RSpec.describe AiUsageSummary, type: :model do
  describe "associations" do
    it "belongs to account" do
      assoc = described_class.reflect_on_association(:account)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "belongs to ai_model" do
      assoc = described_class.reflect_on_association(:ai_model)
      expect(assoc.macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires usage_month" do
      summary = build(:ai_usage_summary, usage_month: nil)
      expect(summary).not_to be_valid
      expect(summary.errors[:usage_month]).to include("can't be blank")
    end

    it "enforces uniqueness of ai_model_id scoped to account and usage_month" do
      existing = create(:ai_usage_summary)
      duplicate = build(:ai_usage_summary,
        account: existing.account,
        ai_model: existing.ai_model,
        usage_month: existing.usage_month)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:ai_model_id]).to include("has already been taken")
    end

    it "allows the same ai_model for different months" do
      existing = create(:ai_usage_summary, usage_month: Date.new(2026, 1, 1))
      different_month = build(:ai_usage_summary,
        account: existing.account,
        ai_model: existing.ai_model,
        usage_month: Date.new(2026, 2, 1))
      expect(different_month).to be_valid
    end

    it "allows the same ai_model and month for different accounts" do
      existing = create(:ai_usage_summary)
      different_account = build(:ai_usage_summary,
        ai_model: existing.ai_model,
        usage_month: existing.usage_month)
      expect(different_account).to be_valid
    end
  end

  describe "defaults" do
    it "defaults numeric fields to 0" do
      summary = described_class.new
      expect(summary._cost_to_us_cents).to eq(0)
      expect(summary._input_tokens).to eq(0)
      expect(summary._output_tokens).to eq(0)
      expect(summary._total_tokens).to eq(0)
    end
  end
end
