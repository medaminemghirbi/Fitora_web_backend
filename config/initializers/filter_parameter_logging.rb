# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # PII / financial fields that don't match any pattern above — found via a
  # security audit logging every request body in cleartext (bank_iban/
  # cnss_number especially: neither shares a substring with :ssn).
  :bank_iban, :bank_name, :cnss_number, :date_of_birth, :phone, :address,
  :emergency_contact_name, :emergency_contact_phone, :notes, :reason, :termination_reason
]
