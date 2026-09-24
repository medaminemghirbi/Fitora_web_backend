# How a member's own app gets switched on: the gym sends an invitation and
# the member chooses their own password from the link. Staff never type, see
# or reset a member's password. Only the digest of the token is stored.
module Invitable
  extend ActiveSupport::Concern

  INVITATION_EXPIRY = 7.days

  class_methods do
    def find_by_invitation_token(raw_token)
      return nil if raw_token.blank?

      record = find_by(invitation_token_digest: Digest::SHA256.hexdigest(raw_token))
      record if record&.invitation_token_valid?(raw_token)
    end
  end

  def generate_invitation_token!
    raw = SecureRandom.urlsafe_base64(32)
    update!(invitation_token_digest: Digest::SHA256.hexdigest(raw), invitation_sent_at: Time.current)
    raw
  end

  def invitation_token_valid?(raw_token)
    return false if invitation_token_digest.blank? || invitation_sent_at.blank?
    return false if invitation_sent_at < INVITATION_EXPIRY.ago

    ActiveSupport::SecurityUtils.secure_compare(invitation_token_digest, Digest::SHA256.hexdigest(raw_token.to_s))
  end

  # Sent, not yet accepted, and still usable.
  def invitation_pending?
    !login_enabled? && invitation_sent_at.present? && invitation_sent_at >= INVITATION_EXPIRY.ago
  end

  # Following the link proves the inbox, so the address counts as verified.
  def accept_invitation!(password)
    if password.blank?
      errors.add(:password, :blank)
      return false
    end

    self.password = password
    self.invitation_token_digest = nil
    self.invitation_sent_at = nil
    self.email_verified_at ||= Time.current
    save
  end
end
