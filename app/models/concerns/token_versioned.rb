# Every JWT carries the token_version its account had when it was issued
# (see JwtService). Moving the version on ends every session at once — which
# is what a new password, a deactivated account or "sign out everywhere"
# should mean. Shared by User and Client.
module TokenVersioned
  extend ActiveSupport::Concern

  included do
    before_save :end_existing_sessions, if: :sessions_should_end?
  end

  # Signs out every device. The caller issues a fresh token if the person
  # making the request should stay signed in on this one.
  def revoke_all_tokens!
    increment!(:token_version) # rubocop:disable Rails/SkipsModelValidations
  end

  def token_current?(version)
    token_version == version.to_i
  end

  private

  def sessions_should_end?
    return false if new_record?

    will_save_change_to_password_digest? || (will_save_change_to_active? && !active?)
  end

  def end_existing_sessions
    self.token_version += 1
  end
end
