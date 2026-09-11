# Error tracking — unhandled exceptions used to only ever surface via a
# support ticket, never automatically. Safely a no-op with no SENTRY_DSN
# set (dev/test never send anywhere); set it in production once the
# project exists in Sentry (see config/deploy.yml's secret list).
#
# sentry-rails (loaded via Bundler.require) hooks in on its own — request
# exceptions, with Rails' own config.filter_parameters (already scrubs
# password/email/token/etc, see filter_parameter_logging.rb) applied
# automatically. sentry-sidekiq does the same for background jobs, which
# otherwise fail completely silently: no request, no user watching, nothing.
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.environment = Rails.env

  # Error tracking only — no performance/APM tracing (that's a separate,
  # quota-costing decision to make later; leave at 0 until then).
  config.traces_sample_rate = 0.0

  # Company/user context is attached per-request from
  # ApplicationController#tag_sentry_context! instead — not global here.
  config.breadcrumbs_logger = [ :active_support_logger ]
end
