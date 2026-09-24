# Shared by User (admin/staff — never superadmin, excluded at the controller
# level, see Api::V1::PasswordResetsController) and Client. Only the token's
# digest is ever persisted; the raw value exists only in the emailed link,
# so a database leak alone can't be used to reset anyone's password.
module PasswordResettable
  extend ActiveSupport::Concern

  TOKEN_EXPIRY = 45.minutes

  class_methods do
    def find_by_reset_password_token(raw_token)
      return nil if raw_token.blank?

      record = find_by(reset_password_token_digest: Digest::SHA256.hexdigest(raw_token))
      record if record&.password_reset_token_valid?(raw_token)
    end
  end

  def generate_password_reset_token!
    raw = SecureRandom.urlsafe_base64(32)
    update!(reset_password_token_digest: Digest::SHA256.hexdigest(raw), reset_password_sent_at: Time.current)
    raw
  end

  def password_reset_token_valid?(raw_token)
    return false if reset_password_token_digest.blank? || reset_password_sent_at.blank?
    return false if reset_password_sent_at < TOKEN_EXPIRY.ago

    ActiveSupport::SecurityUtils.secure_compare(reset_password_token_digest, Digest::SHA256.hexdigest(raw_token.to_s))
  end

  def clear_password_reset_token!
    update_columns(reset_password_token_digest: nil, reset_password_sent_at: nil) # rubocop:disable Rails/SkipsModelValidations
  end
end
