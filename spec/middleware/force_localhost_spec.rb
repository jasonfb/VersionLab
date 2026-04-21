require 'rails_helper'

RSpec.describe ForceLocalhost do
  let(:app) { ->(env) { [200, {}, ["OK"]] } }
  let(:middleware) { described_class.new(app) }

  it "redirects 127.0.0.1 to localhost" do
    env = {
      "HTTP_HOST" => "127.0.0.1:3000",
      "SERVER_PORT" => "3000",
      "PATH_INFO" => "/app/templates",
      "REQUEST_URI" => "/app/templates"
    }
    status, headers, _body = middleware.call(env)
    expect(status).to eq(301)
    expect(headers["Location"]).to eq("http://localhost:3000/app/templates")
  end

  it "passes through for localhost" do
    env = {
      "HTTP_HOST" => "localhost:3000",
      "SERVER_PORT" => "3000",
      "PATH_INFO" => "/app"
    }
    status, _headers, _body = middleware.call(env)
    expect(status).to eq(200)
  end

  it "passes through for other hosts" do
    env = {
      "HTTP_HOST" => "example.com",
      "SERVER_PORT" => "80",
      "PATH_INFO" => "/"
    }
    status, _headers, _body = middleware.call(env)
    expect(status).to eq(200)
  end

  it "handles nil HTTP_HOST" do
    env = { "SERVER_PORT" => "3000", "PATH_INFO" => "/" }
    status, _headers, _body = middleware.call(env)
    expect(status).to eq(200)
  end
end
