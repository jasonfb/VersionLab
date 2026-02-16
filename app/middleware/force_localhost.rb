class ForceLocalhost
  def initialize(app)
    @app = app
  end

  def call(env)
    host = env["HTTP_HOST"]&.split(":")&.first

    if host == "127.0.0.1"
      port = env["SERVER_PORT"]
      location = "http://localhost:#{port}#{env['REQUEST_URI'] || env['PATH_INFO']}"
      [301, { "Location" => location, "Content-Type" => "text/plain" }, ["Use localhost instead of 127.0.0.1"]]
    else
      @app.call(env)
    end
  end
end
