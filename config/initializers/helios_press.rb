# frozen_string_literal: true

Helios::Press.configure do |config|
  config.admin_parent_controller = "Admin::BaseController"
  config.public_parent_controller = "ApplicationController"
end
