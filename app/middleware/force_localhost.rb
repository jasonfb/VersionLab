# frozen_string_literal: true

class ForceLocalhost
  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"].to_s
    unless path.valid_encoding?
      return [ 400, { "Content-Type" => "text/plain" }, [ "Bad Request" ] ]
    end

    host = env["HTTP_HOST"]&.split(":")&.first

    if host == "127.0.0.1"
      port = env["SERVER_PORT"]
      location = "http://localhost:#{port}#{env['REQUEST_URI'] || env['PATH_INFO']}"
      [ 301, { "Location" => location, "Content-Type" => "text/plain" }, [ "Use localhost instead of 127.0.0.1" ] ]
    else
      @app.call(env)
    end
  end
end
