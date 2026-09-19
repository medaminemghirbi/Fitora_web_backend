# How a company has configured the engine to behave.
#
# Fitora runs a boxing club, a Pilates studio, an EMS studio and a gym off
# one codebase. The difference between them is not a `type` column and not a
# branch in the code — it is the values in here. A studio turns rooms on and
# gives itself a twelve-hour cancellation window; a gym leaves rooms off and
# never asks anyone to book at all.
#
# The surface is deliberately CLOSED. The *values* are per-company; the
# *keys* are code. Anything not declared in SCHEMA is dropped on write, so a
# stray key from a client, a half-finished feature or an old release can
# never accumulate in the column. Read #unknown_keys if you need to know what
# a write threw away.
#
# What belongs here: rules and toggles. What does not: anything you would
# ever query, join or constrain on. A member, a booking, a payment, a space
# is a row in a table. A cancellation window is a value in here. See
# docs/TARGET_ARCHITECTURE.md §2.
#
# Immutable: #merge returns a new instance rather than mutating, so a
# settings object handed to a service cannot be changed under it.
class CompanySettings
  # A feature flag says what the product OFFERS this company. It never
  # grants anyone access to anything — permissions are a separate, orthogonal
  # check (see Permission / Role). Turning a feature on must never widen a
  # role. See docs/PERMISSIONS.md §1.
  FEATURES = {
    # Whether sessions can be booked at all. A gym selling unlimited access
    # with a turnstile and no classes turns this off and never sees a
    # booking screen.
    bookings: true,
    # Rooms. Off by default: most gyms are one space, and asking them which
    # room a session is in would be a question with one answer. A Pilates
    # studio with two studios, or an EMS place with four cabins, turns it on.
    spaces: false,
    # Check-in / attendance tracking.
    attendance: true,
    # Whether the product surfaces money at all. Distinct from the `revenue`
    # permission, which decides WHO sees it.
    revenue: true,
    reports: true,
    # Whether members may book themselves from their own app, or whether
    # booking is something the front desk does for them.
    online_booking: true,
    # Whether a full session takes a queue. Off by default: a waitlist nobody
    # manages is worse than a full session.
    waitlist: false
  }.freeze

  # The rules that govern booking, once `features.bookings` is on.
  BOOKING = {
    # How many hours before a session a member may still cancel and get
    # their session credit back. 0 means "right up to the start".
    cancellation_hours: { default: 2, min: 0, max: 168 },
    # How far ahead the schedule is bookable. Stops a member filling every
    # session for the next year.
    booking_opens_days: { default: 14, min: 1, max: 365 },
    # Whether failing to turn up still costs a session off the member's
    # balance. Most places say yes; it is the only thing that makes a
    # no-show cost anything.
    no_show_consumes_session: { default: true }
  }.freeze

  SECTIONS = %i[features booking].freeze

  attr_reader :unknown_keys

  def self.default
    new({})
  end

  def initialize(raw)
    raw = {} unless raw.is_a?(Hash)
    raw = raw.deep_symbolize_keys
    @unknown_keys = []

    @features = build_features(raw[:features])
    @booking = build_booking(raw[:booking])
    collect_unknown_sections(raw)

    freeze
  end

  # --- Features -------------------------------------------------------------

  # `company.settings.feature?(:spaces)` — the one way to ask.
  def feature?(key)
    @features.fetch(key.to_sym, false)
  end

  def features
    @features
  end

  # --- Booking rules --------------------------------------------------------

  def booking
    @booking
  end

  def cancellation_hours = @booking[:cancellation_hours]
  def booking_opens_days = @booking[:booking_opens_days]
  def no_show_consumes_session? = @booking[:no_show_consumes_session]

  # --- Reading and writing --------------------------------------------------

  def to_h
    { features: @features, booking: @booking }
  end

  # Returns a NEW settings object with `patch` applied on top. Only the keys
  # present in the patch change; everything else keeps its current value, so
  # a form that edits one section cannot silently reset another.
  def merge(patch)
    patch = {} unless patch.is_a?(Hash)
    patch = patch.deep_symbolize_keys

    self.class.new(
      features: @features.merge(patch[:features].is_a?(Hash) ? patch[:features] : {}),
      booking: @booking.merge(patch[:booking].is_a?(Hash) ? patch[:booking] : {})
    )
  end

  def ==(other)
    other.is_a?(self.class) && to_h == other.to_h
  end
  alias eql? ==

  def hash = to_h.hash

  private

  def build_features(given)
    given = {} unless given.is_a?(Hash)
    note_unknown(given.keys - FEATURES.keys, "features")

    FEATURES.each_with_object({}) do |(key, default), out|
      out[key] = given.key?(key) ? cast_boolean(given[key], default) : default
    end.freeze
  end

  def build_booking(given)
    given = {} unless given.is_a?(Hash)
    note_unknown(given.keys - BOOKING.keys, "booking")

    BOOKING.each_with_object({}) do |(key, rule), out|
      out[key] = if !given.key?(key)
        rule[:default]
      elsif rule[:default].in?([ true, false ])
        cast_boolean(given[key], rule[:default])
      else
        cast_integer(given[key], rule)
      end
    end.freeze
  end

  # Accepts what a JSON body or an HTML form actually sends — true/false,
  # "true"/"false", 1/0 — and falls back to the default for anything else
  # rather than quietly turning a typo into `false`.
  def cast_boolean(value, default)
    case value
    when true, false then value
    when "true", "1", 1 then true
    when "false", "0", 0 then false
    else default
    end
  end

  # Clamps rather than rejects: a cancellation window of 10_000 hours is a
  # mistake, not an attack, and the nearest legal value is a better answer
  # than a 422 on a settings form.
  def cast_integer(value, rule)
    parsed = Integer(value, exception: false)
    return rule[:default] if parsed.nil?

    parsed.clamp(rule[:min], rule[:max])
  end

  def collect_unknown_sections(raw)
    note_unknown(raw.keys - SECTIONS, nil)
    @unknown_keys.freeze
  end

  def note_unknown(keys, section)
    keys.each { |key| @unknown_keys << [ section, key ].compact.join(".") }
  end
end
