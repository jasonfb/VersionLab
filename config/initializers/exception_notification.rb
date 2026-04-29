require "exception_notification/rails"

ExceptionNotification.configure do |config|
  config.ignored_exceptions += %w[
    ActionController::RoutingError
    ActionController::UnknownFormat
  ]

  config.add_notifier :email, {
    email_prefix: "[VersionLab ERROR] ",
    sender_address: %("VersionLab Errors" <errors@#{ENV.fetch("MAILGUN_DOMAIN", "mg.versionlab.io")}>),
    exception_recipients: ENV.fetch("EXCEPTION_RECIPIENTS", "jason@heliosdev.shop").split(",").map(&:strip).reject(&:empty?),
    delivery_method: :mailgun,
    mailgun_settings: {
      api_key: ENV.fetch("MAILGUN_API_KEY", ""),
      domain: ENV.fetch("MAILGUN_DOMAIN", "mg.versionlab.io"),
      api_host: ENV.fetch("MAILGUN_API_HOST", "api.mailgun.net")
    }
  }
end
