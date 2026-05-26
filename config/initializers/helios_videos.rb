# frozen_string_literal: true

Helios::Videos.configure do |config|
  config.processor = :mux
  config.admin_parent_controller = "Admin::BaseController"
  config.mux_token_id = ENV["MUX_TOKEN_ID"]
  config.mux_token_secret = ENV["MUX_TOKEN_SECRET"]
end
