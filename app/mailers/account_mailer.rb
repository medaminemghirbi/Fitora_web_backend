# The first real transactional mailer in the app (ApplicationMailer existed
# but nothing subclassed it yet) — password reset + email verification,
# shared by User (owner/staff — never admin, see
# Api::V1::PasswordResetsController) and Client.
class AccountMailer < ApplicationMailer
  # The Angular SPA's own origin — never Rails' own default_url_options
  # (that's tuned for :host/:port that make sense for Rails route helpers;
  # in development the SPA lives on a different port entirely, and in
  # production it's baked into APP_HOST, the same var config/environments/
  # production.rb already uses for its own default_url_options).
  FRONTEND_URL = Rails.env.production? ? "https://#{ENV.fetch('APP_HOST', 'app.fitora.com')}" : ENV.fetch("FRONTEND_URL", "http://localhost:4200")

  def password_reset(record, raw_token)
    @record = record
    @first_name = record.respond_to?(:first_name) ? record.first_name : nil
    @reset_url = "#{FRONTEND_URL}/auth/reset-password?token=#{raw_token}"
    @expires_in_minutes = PasswordResettable::TOKEN_EXPIRY.to_i / 60

    mail(to: record.email, subject: "Réinitialisez votre mot de passe Fitora")
  end

  def email_verification(record, raw_token)
    @record = record
    @first_name = record.respond_to?(:first_name) ? record.first_name : nil
    @verify_url = "#{FRONTEND_URL}/verify-email?token=#{raw_token}"

    mail(to: record.email, subject: "Confirmez votre adresse e-mail Fitora")
  end
end
