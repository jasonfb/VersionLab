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

  describe "before_create :compute_cost" do
    let(:ai_model) do
      create(:ai_model,
        input_cost_per_mtok_cents: 300,
        output_cost_per_mtok_cents: 1500)
    end

    it "computes cost from token counts and model pricing" do
      log = create(:ai_log,
        ai_model: ai_model,
        ai_service: ai_model.ai_service,
        prompt_tokens: 1_000_000,
        completion_tokens: 500_000,
        total_tokens: 1_500_000,
        call_type: "email")
      # input: (1_000_000 * 300) / 1_000_000 = 300 cents
      # output: (500_000 * 1500) / 1_000_000 = 750 cents
      # total: ceil(1050) = 1050 cents
      expect(log._cost_to_us_cents).to eq(1050)
    end

    it "stores fractional cent cost" do
      log = create(:ai_log,
        ai_model: ai_model,
        ai_service: ai_model.ai_service,
        prompt_tokens: 1,
        completion_tokens: 1,
        total_tokens: 2,
        call_type: "email")
      # input: (1 * 300) / 1_000_000 = 0.0003
      # output: (1 * 1500) / 1_000_000 = 0.0015
      # total: 0.0018 cents
      expect(log._cost_to_us_cents).to eq(BigDecimal("0.0018"))
    end

    it "skips cost computation when ai_model is nil" do
      log = create(:ai_log, ai_model: nil, prompt_tokens: 1000, completion_tokens: 500)
      expect(log._cost_to_us_cents).to be_nil
    end

    it "skips cost computation when model has no pricing" do
      model_no_pricing = create(:ai_model, input_cost_per_mtok_cents: nil, output_cost_per_mtok_cents: nil)
      log = create(:ai_log,
        ai_model: model_no_pricing,
        ai_service: model_no_pricing.ai_service,
        prompt_tokens: 1000,
        completion_tokens: 500,
        call_type: "email")
      expect(log._cost_to_us_cents).to be_nil
    end

    it "handles nil token counts gracefully" do
      log = create(:ai_log,
        ai_model: ai_model,
        ai_service: ai_model.ai_service,
        prompt_tokens: nil,
        completion_tokens: nil,
        total_tokens: nil,
        call_type: "email")
      expect(log._cost_to_us_cents).to eq(0)
    end
  end

  describe "after_create :update_usage_summary" do
    let(:ai_model) do
      create(:ai_model,
        input_cost_per_mtok_cents: 300,
        output_cost_per_mtok_cents: 1500)
    end
    let(:account) { create(:account) }

    it "creates an AiUsageSummary record on first log" do
      expect {
        create(:ai_log,
          account: account,
          ai_model: ai_model,
          ai_service: ai_model.ai_service,
          prompt_tokens: 1000,
          completion_tokens: 500,
          total_tokens: 1500,
          call_type: "email")
      }.to change(AiUsageSummary, :count).by(1)
    end

    it "accumulates tokens into existing summary for same account/model/month" do
      create(:ai_log,
        account: account,
        ai_model: ai_model,
        ai_service: ai_model.ai_service,
        prompt_tokens: 1000,
        completion_tokens: 500,
        total_tokens: 1500,
        call_type: "email")

      expect {
        create(:ai_log,
          account: account,
          ai_model: ai_model,
          ai_service: ai_model.ai_service,
          prompt_tokens: 2000,
          completion_tokens: 1000,
          total_tokens: 3000,
          call_type: "ad")
      }.not_to change(AiUsageSummary, :count)

      summary = AiUsageSummary.find_by(account: account, ai_model: ai_model)
      expect(summary._input_tokens).to eq(3000)
      expect(summary._output_tokens).to eq(1500)
      expect(summary._total_tokens).to eq(4500)
    end

    it "skips summary update when ai_model_id is nil" do
      expect {
        create(:ai_log, account: account, ai_model: nil, call_type: "email")
      }.not_to change(AiUsageSummary, :count)
    end
  end
end
