require 'rails_helper'

RSpec.describe AiProviders::Base do
  let(:provider) { described_class.new(api_key: "test-key") }

  describe "#complete" do
    it "raises NotImplementedError" do
      expect { provider.complete(model: "m", messages: []) }.to raise_error(NotImplementedError)
    end
  end

  describe "#generate_image" do
    it "raises NotImplementedError" do
      expect { provider.generate_image(model: "m", prompt: "p") }.to raise_error(NotImplementedError)
    end
  end

  describe AiProviders::Base::RateLimitError do
    it "stores retry_after" do
      error = described_class.new(30)
      expect(error.retry_after).to eq(30.0)
      expect(error.message).to eq("Rate limit exceeded")
    end

    it "handles nil retry_after" do
      error = described_class.new(nil)
      expect(error.retry_after).to be_nil
    end
  end

  describe "#with_retries (private)" do
    it "retries on rate limit with exponential backoff" do
      attempts = 0
      allow(provider).to receive(:sleep)

      expect {
        provider.send(:with_retries, service_name: "Test") do
          attempts += 1
          raise AiProviders::Base::RateLimitError.new(nil) if attempts < 3
          "success"
        end
      }.not_to raise_error

      expect(attempts).to eq(3)
    end

    it "raises after MAX_RETRIES" do
      allow(provider).to receive(:sleep)

      expect {
        provider.send(:with_retries, service_name: "Test") do
          raise AiProviders::Base::RateLimitError.new(nil)
        end
      }.to raise_error(AiProviders::Base::Error, /rate limit exceeded after/)
    end

    it "uses retry_after when provided" do
      attempts = 0
      allow(provider).to receive(:sleep)

      provider.send(:with_retries, service_name: "Test") do
        attempts += 1
        raise AiProviders::Base::RateLimitError.new(5) if attempts == 1
        "done"
      end

      expect(provider).to have_received(:sleep).with(5.0)
    end
  end

  describe "#http_post (private)" do
    it "makes an HTTPS POST request" do
      uri = URI("https://api.example.com/v1/test")
      http_double = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http_double)
      allow(http_double).to receive(:use_ssl=)
      allow(http_double).to receive(:read_timeout=)
      allow(http_double).to receive(:open_timeout=)
      response = instance_double(Net::HTTPResponse, code: "200", body: "{}")
      allow(http_double).to receive(:request).and_return(response)

      result = provider.send(:http_post, uri, { key: "value" }, { "X-Custom" => "header" })
      expect(result.code).to eq("200")
    end
  end
end
