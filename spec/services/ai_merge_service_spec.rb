require 'rails_helper'

RSpec.describe AiMergeService do
  let(:account) { create(:account) }
  let(:client) { create(:client, account: account) }
  let(:ai_service) { create(:ai_service, slug: "openai") }
  let(:ai_model) { create(:ai_model, ai_service: ai_service, for_text: true) }
  let!(:ai_key) { create(:ai_key, ai_service: ai_service) }
  let(:template) { create(:email_template, client: client, raw_source_html: "<p>Hello</p>") }
  let(:section) { create(:email_template_section, email_template: template) }
  let!(:variable) { create(:template_variable, email_template_section: section, variable_type: "text", name: "Headline", default_value: "Welcome!") }
  let(:audience) { create(:audience, client: client, name: "Young Donors") }
  let(:email) do
    create(:email, client: client, email_template: template,
           ai_service: ai_service, ai_model: ai_model)
  end

  before do
    create(:email_audience, email: email, audience: audience)
  end

  let(:ai_response) do
    {
      content: { variable.id => "Hello Young Donors!" }.to_json,
      prompt_tokens: 100,
      completion_tokens: 50,
      total_tokens: 150
    }
  end

  let(:provider) { instance_double(AiProviders::Openai, complete: ai_response) }

  before do
    allow(AiProviders::Factory).to receive(:for_text).and_return(provider)
  end

  describe "#call" do
    it "creates an email version with variable values" do
      described_class.new(email).call

      version = email.email_versions.find_by(audience: audience)
      expect(version).to be_present
      expect(version.state).to eq("active")
      expect(version.email_version_variables.count).to eq(1)
      expect(version.email_version_variables.first.value).to eq("Hello Young Donors!")
    end

    it "calls the AI provider with messages" do
      described_class.new(email).call
      expect(provider).to have_received(:complete).once
    end

    it "logs the AI call" do
      expect { described_class.new(email).call }.to change(AiLog, :count).by(1)

      log = AiLog.last
      expect(log.call_type).to eq("email")
      expect(log.ai_model).to eq(ai_model)
    end

    it "raises when no text variables exist" do
      variable.update!(variable_type: "image")
      expect { described_class.new(email).call }.to raise_error(AiMergeService::Error, /No text variables/)
    end

    it "raises when no audiences are assigned" do
      email.email_audiences.destroy_all
      expect { described_class.new(email).call }.to raise_error(AiMergeService::Error, /No audiences/)
    end

    it "raises on empty AI response" do
      allow(provider).to receive(:complete).and_return(content: "", prompt_tokens: 0, completion_tokens: 0, total_tokens: 0)
      expect { described_class.new(email).call }.to raise_error(AiMergeService::Error, /Empty response/)
    end

    it "raises on invalid JSON response" do
      allow(provider).to receive(:complete).and_return(content: "not json", prompt_tokens: 0, completion_tokens: 0, total_tokens: 0)
      expect { described_class.new(email).call }.to raise_error(AiMergeService::Error, /Failed to parse/)
    end

    it "skips audiences that already have active versions" do
      create(:email_version, email: email, audience: audience,
             ai_service: ai_service, ai_model: ai_model, state: "active")
      described_class.new(email).call
      expect(provider).not_to have_received(:complete)
    end

    it "scopes to specific audience_ids when provided" do
      other_audience = create(:audience, client: client, name: "Old Donors")
      create(:email_audience, email: email, audience: other_audience)

      described_class.new(email, audience_ids: [audience.id]).call
      expect(provider).to have_received(:complete).once
    end

    it "attaches to a pre-existing generating version during regeneration" do
      pre_version = create(:email_version, email: email, audience: audience,
                           ai_service: ai_service, ai_model: ai_model, state: "generating")

      described_class.new(email).call

      pre_version.reload
      expect(pre_version.state).to eq("active")
      expect(pre_version.email_version_variables.count).to eq(1)
    end

    it "includes rejection context in the prompt" do
      rejection = { audience.id.to_s => "Too formal" }
      described_class.new(email, rejection_context: rejection).call

      call_args = provider.method(:complete).owner # just verify it was called
      expect(provider).to have_received(:complete) do |args|
        user_content = args[:messages].last[:content]
        expect(user_content).to include("Too formal")
      end
    end

    it "wraps provider errors as AiMergeService::Error" do
      allow(provider).to receive(:complete).and_raise(AiProviders::Base::Error, "API down")
      expect { described_class.new(email).call }.to raise_error(AiMergeService::Error, "API down")
    end

    context "with brand profile" do
      let!(:industry) { create(:industry, name: "Nonprofit") }
      let!(:org_type) { create(:organization_type, name: "Charity") }
      let!(:brand_profile) do
        create(:brand_profile, client: client,
               organization_name: "Test Org", industry: industry, organization_type: org_type,
               mission_statement: "Help the world", core_programs: "Education",
               approved_vocabulary: "empower, uplift", blocked_vocabulary: "cheap",
               link_color: "#0000FF", underline_links: true, bold_links: true)
      end

      it "includes brand profile in the prompt" do
        described_class.new(email).call
        expect(provider).to have_received(:complete) do |args|
          content = args[:messages].last[:content]
          expect(content).to include("Brand Profile")
          expect(content).to include("Test Org")
          expect(content).to include("Nonprofit")
        end
      end
    end

    context "with campaign context" do
      let(:campaign) { create(:campaign, client: client, ai_summary: "Campaign about spring donations") }

      before { email.update!(campaign: campaign) }

      it "includes campaign summary in the prompt" do
        described_class.new(email).call
        expect(provider).to have_received(:complete) do |args|
          content = args[:messages].last[:content]
          expect(content).to include("Campaign Summary")
          expect(content).to include("spring donations")
        end
      end
    end

    context "with email context and ai_summary" do
      before do
        email.update!(context: "Focus on urgency", ai_summary: "Donors responded well to appeals")
      end

      it "includes merge context in the prompt" do
        described_class.new(email).call
        expect(provider).to have_received(:complete) do |args|
          content = args[:messages].last[:content]
          expect(content).to include("Merge Context")
          expect(content).to include("Focus on urgency")
          expect(content).to include("Email Reference Documents Summary")
        end
      end
    end

    context "with audience intelligence fields" do
      before do
        audience.update!(
          executive_summary: "High-value donors who lapsed",
          demographics_and_financial_capacity: "Income $100k+",
          motivational_drivers_and_messaging_framework: "Drive by impact"
        )
      end

      it "includes audience intelligence in the prompt" do
        described_class.new(email).call
        expect(provider).to have_received(:complete) do |args|
          content = args[:messages].last[:content]
          expect(content).to include("Audience Intelligence Profile")
          expect(content).to include("High-value donors")
        end
      end
    end

    context "with autolink settings" do
      let!(:autolink_setting) do
        email.email_section_autolink_settings.create!(
          email_template_section: section,
          autolink_mode: "link_relevant_text",
          link_mode: "user_url",
          url: "https://donate.example.com"
        )
      end

      before do
        variable.update!(slot_role: "subheadline")
      end

      it "includes linking instructions in prompt" do
        described_class.new(email).call
        expect(provider).to have_received(:complete) do |args|
          content = args[:messages].last[:content]
          expect(content).to include("Linking Instructions")
          expect(content).to include("https://donate.example.com")
        end
      end

      it "includes autolinking instruction in system prompt" do
        described_class.new(email).call
        expect(provider).to have_received(:complete) do |args|
          system_content = args[:messages].first[:content]
          expect(system_content).to include("linking instructions")
        end
      end
    end
  end
end
