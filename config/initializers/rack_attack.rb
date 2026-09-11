# Brute-force protection for the real login endpoint — POST
# /api/v1/auth/login had no rate limiting at all until now: an attacker
# could try passwords as fast as the network allowed, for any account
# (owner/staff/client all share this one endpoint). Also lightly covers
# password-reset requests and owner self-registration, the other
# unauthenticated account surfaces, to stop them being scripted for
# inbox-spam or mass account creation.
#
# Disabled in test by default — spec/requests/rack_attack_spec.rb flips it
# on for the duration of its own examples only.
Rack::Attack.enabled = !Rails.env.test?

# Shared across Puma workers (WEB_CONCURRENCY in config/deploy.yml) — an
# in-memory store would count separately per worker, making the limits
# below several times more permissive than they look. Redis is already a
# hard dependency (Sidekiq/ActionCable).
Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
  url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
)

# Short, tight window — stops a fast automated guessing burst outright.
Rack::Attack.throttle("logins/ip/burst", limit: 5, period: 20.seconds) do |req|
  req.ip if req.post? && req.path == "/api/v1/auth/login"
end

# Longer window, higher ceiling — catches a slower attempt that stays
# under the burst limit but is still clearly not a human typing a password.
Rack::Attack.throttle("logins/ip/sustained", limit: 20, period: 5.minutes) do |req|
  req.ip if req.post? && req.path == "/api/v1/auth/login"
end

# Keyed on the attempted email rather than the caller's IP — the burst/
# sustained throttles above are per-IP, so a distributed attempt (many
# IPs, one targeted account) would sail through both. Cheaply defeated by
# also throttling per email tried, regardless of source.
Rack::Attack.throttle("logins/email", limit: 5, period: 20.seconds) do |req|
  next unless req.post? && req.path == "/api/v1/auth/login"

  req.params["email"].to_s.downcase.strip.presence
end

Rack::Attack.throttle("password_resets/ip", limit: 5, period: 1.minute) do |req|
  req.ip if req.post? && req.path == "/api/v1/password_resets"
end

# Owner self-signup — unauthenticated, creates a User and immediately
# emails the address given (no ownership check). With no limit an attacker
# could script mass account creation or use it to email-bomb a third party
# through Fitora's own mailer at will.
Rack::Attack.throttle("register/ip", limit: 5, period: 10.minutes) do |req|
  req.ip if req.post? && req.path == "/api/v1/auth/register"
end

Rack::Attack.throttled_responder = lambda do |_request|
  [ 429, { "Content-Type" => "application/json" }, [ { error: "rate_limited" }.to_json ] ]
end
