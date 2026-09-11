# Fitora Backend

Rails 8 API backend for Fitora — a multi-tenant gym/studio management platform
(clients, bookings, sessions, contracts, staff, payroll, attendance, and
real-time notifications).

## Stack

- **Ruby** 3.4.7 (see [.ruby-version](.ruby-version))
- **Rails** 8.1 (`config.api_only = true`)
- **PostgreSQL** — primary datastore, UUID primary keys everywhere
- **Redis** — Sidekiq queue backend + ActionCable pub/sub
- **Sidekiq** (+ `sidekiq-cron`) — background jobs (expiry scans, notification fan-out)
- **ActionCable** — real-time notifications
- **JWT** (`jwt` gem) — API authentication
- **Kamal** — Docker-based deployment
- **Sentry** — error tracking (`sentry-ruby`, `sentry-rails`, `sentry-sidekiq`)

## Requirements

- Ruby 3.4.7 (use [rbenv](https://github.com/rbenv/rbenv)/[asdf](https://asdf-vm.com/) with the provided `.ruby-version`)
- PostgreSQL 14+
- Redis 6+

## Setup

```bash
# Install dependencies
bin/setup --skip-server   # or: bundle install

# Configure environment
cp .env.example .env      # then fill in local values as needed

# Create and migrate the database
bin/rails db:create db:schema:load
```

## Running the app

```bash
bin/rails server           # API on http://localhost:3000
bundle exec sidekiq -c 5   # background job worker (needed for notifications/scans)
```

Or run both with [foreman](https://github.com/ddollar/foreman) via `Procfile.dev`:

```bash
foreman start -f Procfile.dev
```

The Sidekiq dashboard is mounted at `/sidekiq` — open in development, or in
other environments once `SIDEKIQ_WEB_PASSWORD` is set (HTTP basic auth).

## Configuration

All runtime configuration is via environment variables — see
[.env.example](.env.example) for the full list and inline documentation
(datastores, CORS origins, SMS provider, Sentry, etc). Locally these are
loaded from `.env` by `dotenv-rails`; in production they're set on the host /
in the Kamal deploy config.

## Testing

The test suite uses RSpec, FactoryBot, and a real PostgreSQL test database.

```bash
bin/rails db:test:prepare   # first run / after schema changes
bundle exec rspec           # full suite
bundle exec rspec spec/models/client_spec.rb   # single file
```

## Linting & static analysis

```bash
bundle exec rubocop                 # style (Omakase Rails style + house cops in lib/rubocop/cop/fitora)
bundle exec brakeman --no-pager     # security static analysis
```

## Continuous Integration

Every push and pull request runs lint, security scan, and the full test suite —
see [.github/workflows/ci.yml](.github/workflows/ci.yml).

## Deployment

Deployed as a Docker container via [Kamal](https://kamal-deploy.org/) — see
[config/deploy.yml](config/deploy.yml) and the [Dockerfile](Dockerfile).

```bash
bin/kamal deploy
```

## Project structure

- `app/controllers/api/v1` — versioned JSON API, namespaced by role where relevant (`admin/`, `owner/`, `me/`)
- `app/services` — single-purpose service objects for business logic (bookings, contracts, payroll, recurring schedules, notifications, …)
- `app/models/concerns` — shared model behavior (email verification, password reset, photo attachment)
- `app/jobs` — Sidekiq background jobs, mostly scheduled scans (see `config/sidekiq_cron.yml`)
- `app/policies` — authorization
- `app/serializers` — JSON response shaping
- `lib/rubocop/cop/fitora` — house Rubocop cops (e.g. tenant-scoping enforcement)
