class JwtService
  ALGORITHM = "HS256".freeze
  EXPIRATION = 7.days

  class DecodeError < StandardError; end

  # impersonator_id is only set for an admin-initiated impersonation session
  # (see Api::V1::Admin::CompaniesController#impersonate) — it lets
  # authenticate_request! surface who is really behind the wheel without
  # changing what current_user resolves to (still the impersonated owner, so
  # every existing owner-only guard/capability check keeps working as-is).
  #
  # client_id is the other kind of token — issued for a Client's own mobile
  # login (see Api::V1::AuthController#login), mutually exclusive with
  # user_id. Kept as a separate keyword rather than folding Client into User
  # so every existing owner/staff/admin call site (positional user_id) is
  # unaffected.
  def self.encode(user_id = nil, client_id: nil, impersonator_id: nil)
    payload = { exp: EXPIRATION.from_now.to_i }
    payload[:user_id] = user_id if user_id
    payload[:client_id] = client_id if client_id
    payload[:impersonator_id] = impersonator_id if impersonator_id
    JWT.encode(payload, secret, ALGORITHM)
  end

  def self.decode(token)
    payload = JWT.decode(token, secret, true, algorithm: ALGORITHM).first
    { user_id: payload["user_id"], client_id: payload["client_id"], impersonator_id: payload["impersonator_id"] }
  rescue JWT::DecodeError, JWT::ExpiredSignature
    raise DecodeError
  end

  def self.secret
    Rails.application.secret_key_base
  end
end
