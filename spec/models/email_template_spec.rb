# == Schema Information
#
# Table name: email_templates
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  name                     :string
#  original_raw_source_html :text
#  raw_source_html          :text
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  client_id                :uuid             not null
#
require 'rails_helper'

RSpec.describe EmailTemplate, type: :model do
  describe "associations" do
    it "belongs to client" do
      assoc = described_class.reflect_on_association(:client)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "has many sections" do
      assoc = described_class.reflect_on_association(:sections)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:class_name]).to eq("EmailTemplateSection")
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has many template_variables through sections" do
      assoc = described_class.reflect_on_association(:template_variables)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:sections)
    end

    it "has many emails" do
      assoc = described_class.reflect_on_association(:emails)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it "has one template_import" do
      assoc = described_class.reflect_on_association(:template_import)
      expect(assoc.macro).to eq(:has_one)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end
  end

  describe "before_create :snapshot_original_html" do
    it "sets original_raw_source_html from raw_source_html on create" do
      template = create(:email_template, raw_source_html: "<p>Hello</p>")
      expect(template.original_raw_source_html).to eq("<p>Hello</p>")
    end

    it "does not overwrite original_raw_source_html if already set" do
      template = create(:email_template, raw_source_html: "<p>New</p>", original_raw_source_html: "<p>Original</p>")
      expect(template.original_raw_source_html).to eq("<p>Original</p>")
    end
  end

  describe "#reset_to_original!" do
    it "restores raw_source_html to the original and destroys sections" do
      template = create(:email_template, raw_source_html: "<p>Original</p>")
      template.update!(raw_source_html: "<p>Modified</p>")

      sections_relation = double("sections_relation")
      allow(template).to receive(:sections).and_return(sections_relation)
      allow(sections_relation).to receive(:destroy_all)

      template.reset_to_original!

      expect(template.raw_source_html).to eq("<p>Original</p>")
      expect(sections_relation).to have_received(:destroy_all)
    end
  end

  describe "#reset_to_blank!" do
    it "nils out html fields and destroys sections" do
      template = create(:email_template, raw_source_html: "<p>Hello</p>")

      sections_relation = double("sections_relation")
      allow(template).to receive(:sections).and_return(sections_relation)
      allow(sections_relation).to receive(:destroy_all)

      template.reset_to_blank!

      expect(template.raw_source_html).to be_nil
      expect(template.original_raw_source_html).to be_nil
      expect(sections_relation).to have_received(:destroy_all)
    end
  end

  describe "#render_html" do
    let(:template) { create(:email_template, raw_source_html: html) }

    context "when raw_source_html is blank" do
      let(:html) { nil }

      it "returns an empty string" do
        expect(template.render_html).to eq("")
      end
    end

    context "with text variable substitution" do
      let(:var_id) { SecureRandom.uuid }
      let(:html) { "<p>Hello {{vl:#{var_id}}}</p>" }

      it "substitutes with override value when provided" do
        result = template.render_html(var_id => "World")
        expect(result).to include("Hello World")
        expect(result).not_to include("{{vl:")
      end

      it "substitutes with default value from template_variables when no override" do
        variable = instance_double(TemplateVariable, id: var_id, default_value: "Default")
        allow(template).to receive(:template_variables).and_return([variable])

        result = template.render_html
        expect(result).to include("Hello Default")
      end

      it "substitutes with empty string when no override and no matching variable" do
        allow(template).to receive(:template_variables).and_return([])

        result = template.render_html
        expect(result).to include("Hello ")
        expect(result).not_to include("{{vl:")
      end
    end

    context "with image variable substitution via data-vl-var" do
      let(:var_id) { SecureRandom.uuid }
      let(:html) { %(<img src="old.jpg" data-vl-var="#{var_id}" />) }

      it "replaces img src with override value" do
        result = template.render_html(var_id => "new.jpg")
        doc = Nokogiri::HTML.fragment(result)
        img = doc.at_css("img")
        expect(img["src"]).to eq("new.jpg")
      end

      it "strips data-vl-var attribute from output" do
        result = template.render_html(var_id => "new.jpg")
        expect(result).not_to include("data-vl-var")
      end

      it "strips data-vl-var even without overrides" do
        result = template.render_html
        expect(result).not_to include("data-vl-var")
      end
    end
  end
end
