class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "VersionLab <no-reply@versionlab.io>"),
          reply_to: ENV.fetch("MAIL_REPLY_TO", "support@versionlab.io")
  layout "mailer"
end
