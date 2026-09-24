class ApplicationMailer < ActionMailer::Base
  # Was the Rails placeholder ("from@example.com") — never actually
  # configured, because AccountMailer is the first mailer in this app that
  # sends anything for real.
  default from: ENV.fetch("MAIL_FROM", "Gymly <no-reply@gymly.io>")
  layout "mailer"
end
