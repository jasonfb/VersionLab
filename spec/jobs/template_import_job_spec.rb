require 'rails_helper'

RSpec.describe TemplateImportJob do
  let(:client) { create(:client) }
  let(:template) { create(:email_template, client: client, name: "Import Test") }
  let(:import) { create(:template_import, email_template: template, import_type: "bundled") }

  before do
    allow(ActionCable.server).to receive(:broadcast)
  end

  describe "#perform" do
    context "with a bundled ZIP import" do
      let(:zip_buffer) do
        buffer = StringIO.new
        Zip::OutputStream.write_buffer(buffer) do |out|
          out.put_next_entry("index.html")
          out.write("<html><body><img src='images/logo.png'/></body></html>")
          out.put_next_entry("images/logo.png")
          out.write(File.read(Rails.root.join("spec/fixtures/test.txt")))
        end
        buffer.rewind
        buffer
      end

      before do
        blob = ActiveStorage::Blob.create_and_upload!(
          io: zip_buffer,
          filename: "template.zip",
          content_type: "application/zip"
        )
        import.source_file.attach(blob)
      end

      it "processes the ZIP and updates template HTML" do
        described_class.new.perform(import.id)

        import.reload
        expect(import.state).to eq("completed")
        template.reload
        expect(template.raw_source_html).to be_present
      end

      it "broadcasts state updates" do
        described_class.new.perform(import.id)
        expect(ActionCable.server).to have_received(:broadcast).at_least(:twice)
      end
    end

    context "when import fails" do
      it "sets state to failed with error message" do
        expect { described_class.new.perform(import.id) }.to raise_error(StandardError)

        import.reload
        expect(import.state).to eq("failed")
        expect(import.error_message).to be_present
      end
    end
  end
end
