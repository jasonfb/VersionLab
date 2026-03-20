module AiProviders
  class Base
    class Error < StandardError; end

    class RateLimitError < Error
      attr_reader :retry_after

      def initialize(retry_after = nil)
        @retry_after = retry_after&.to_f
        super("Rate limit exceeded")
      end
    end

    MAX_RETRIES = 5

    def initialize(api_key:)
      @api_key = api_key
    end

    # Text providers implement this. Returns:
    #   { content: String, prompt_tokens: Integer, completion_tokens: Integer, total_tokens: Integer }
    def complete(model:, messages:, temperature: 0.7, json_mode: false)
      raise NotImplementedError, "#{self.class.name}#complete is not implemented"
    end

    # Image providers implement this. Returns:
    #   { images: [{ data: String (base64), mime_type: String }] }
    def generate_image(model:, prompt:, **opts)
      raise NotImplementedError, "#{self.class.name}#generate_image is not implemented"
    end

    private

    def with_retries(service_name: self.class.name)
      attempts = 0
      begin
        attempts += 1
        yield
      rescue RateLimitError => e
        raise Error, "#{service_name} rate limit exceeded after #{MAX_RETRIES} retries" if attempts > MAX_RETRIES
        wait = (e.retry_after && e.retry_after > 0) ? e.retry_after : (10 * (2**(attempts - 1)))
        Rails.logger.info("#{service_name} rate limit hit, waiting #{wait}s (attempt #{attempts})")
        sleep(wait)
        retry
      end
    end

    def http_post(uri, body, headers)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 120
      http.open_timeout = 10

      request = Net::HTTP::Post.new(uri.path + (uri.query ? "?#{uri.query}" : ""))
      headers.each { |k, v| request[k] = v }
      request["content-type"] = "application/json"
      request.body = body.to_json

      http.request(request)
    end
  end
end
