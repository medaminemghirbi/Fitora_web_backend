class Contract < ApplicationRecord
  belongs_to :client
  belongs_to :contract_type
  # What this contract books — OPTIONAL, and the absence carries meaning:
  #
  #   activity present → this contract is for that one activity
  #   activity NULL    → this contract covers every activity its plan covers
  #
  # That second case is how an "all-access" membership is sold. Both are read
  # through #covers_activity?; never compare activity_id directly.
  belongs_to :activity, optional: true
  belongs_to :company
  belongs_to :created_by, class_name: "User", optional: true

  has_many :contract_periods, dependent: :destroy
  has_many :payments, through: :contract_periods
  has_many :bookings, through: :contract_periods

  # Scoped by activity too: the same client can hold the same plan more than
  # once as long as each contract is for a different activity. Two
  # all-access contracts on one plan (both activity_id NULL) still collide,
  # which is right — that is the same membership sold twice.
  validates :client_id, uniqueness: { scope: [ :contract_type_id, :activity_id ] }

  # Every reasoning about "the client's contract" (status, dates, price,
  # remaining sessions) is really about their CURRENT term — the period in
  # force today — so it's delegated rather than stored flat on Contract
  # itself.
  # Not memoized: #reload doesn't know to clear a plain ivar, and this
  # isn't a hot enough path to be worth the staleness risk.
  delegate :status, :starts_at, :expires_at, :remaining_bookings, :discount, :final_price, :payment_status,
           :pending?, :active?, :expired?, :cancelled?, :unpaid?, :paid?,
           to: :current_period, allow_nil: true

  # The period IN FORCE TODAY — the latest one that has already started,
  # not simply the latest one on file. The difference is the whole point of
  # renewing early: a renewal queued while the running term still has weeks
  # left is a FUTURE period, and reading it as "current" would hide the term
  # the member is actually living under (its dates, its price, its remaining
  # sessions) behind one that hasn't begun. Both are kept; only one is
  # current. Before anything has started — a contract sold to start next
  # month — the nearest upcoming period stands in, so the contract is never
  # period-less.
  def current_period
    started, upcoming = periods_by_time
    started.last || upcoming.first
  end

  # The renewals waiting behind the current term, soonest first. Never
  # touched by the everyday reads above: they exist to be SHOWN, so nobody
  # sells the same month twice.
  def upcoming_periods
    _started, upcoming = periods_by_time
    upcoming
  end

  def next_period
    upcoming_periods.first
  end

  # Everything still owed on this contract: the current term plus any
  # renewal queued behind it. A renewal is sold unpaid, and since it is no
  # longer the current period, reading the current one alone would make the
  # money the gym is owed for it disappear from the desk's screens.
  def unpaid_periods
    started, upcoming = periods_by_time
    ([ started.last ] + upcoming).compact.reject(&:cancelled?).select(&:unpaid?)
  end

  # What "Encaisser" settles: the oldest thing still owed, so a queued
  # renewal is collected once the current term has been.
  def payable_period
    unpaid_periods.first
  end

  def amount_due
    unpaid_periods.sum { |p| p.final_price.to_f }
  end

  # The end of everything already sold — where a renewal has to start so it
  # queues behind the current term instead of overlapping it, including when
  # a renewal is queued behind an earlier renewal. A cancelled period sold
  # nothing, so re-subscribing after a cancellation starts today rather than
  # at the end of the term that was given up.
  def covered_through
    contract_periods.reject(&:cancelled?).filter_map(&:expires_at).max
  end

  # `period:` lets a caller re-check eligibility against an already-locked
  # ContractPeriod row instead of the unlocked current_period lookup — see
  # Bookings::Create, which re-verifies through a `SELECT ... FOR UPDATE`
  # row after picking a candidate contract, closing the check-then-act
  # window a concurrent booking against the same contract could otherwise
  # slip through (same class of race the Session capacity lock exists for).
  def usable_for?(activity:, period: current_period)
    return false unless period&.active? && (period.expires_at.nil? || period.expires_at >= Time.current)
    return false if contract_type.booking_limit.present? && !contract_type.unlimited_bookings? && period.remaining_bookings.to_i <= 0
    covers_activity?(activity)
  end

  # Does this contract let the member into this activity?
  #
  # A contract pinned to one activity answers on that alone. An all-access
  # contract (activity_id NULL) defers to its plan, which is the only place
  # the answer lives. Either way the plan has the final say: an activity
  # dropped from the plan stops being covered by contracts sold under it.
  def covers_activity?(activity)
    return false if activity.blank?
    return false unless contract_type.grants_access_to?(activity: activity)

    activity_id.nil? || activity_id == activity.id
  end

  # True for the "covers everything on the plan" kind.
  def all_access?
    activity_id.nil?
  end

  # The activities this contract can actually book, for display.
  def covered_activities
    all_access? ? contract_type.activities : [ activity ].compact
  end

  # What this contract is for, in words — the one activity it names, or the
  # names of everything its plan covers. Never nil: an all-access contract
  # has no `activity` to call `.name` on, and every caller that used to
  # assume one is reading this instead.
  def activity_label
    return activity.name if activity

    names = contract_type.activities.order(:name).pluck(:name)
    names.presence&.to_sentence || "—"
  end

  def consume_booking!(period: current_period)
    return if contract_type.unlimited_bookings?
    return if period&.remaining_bookings.nil?

    period.decrement!(:remaining_bookings)
  end

  def restore_booking!
    return if contract_type.unlimited_bookings?
    return if current_period&.remaining_bookings.nil?

    current_period.increment!(:remaining_bookings)
  end

  private

  # Splits the contract's periods in two at "now", each side in chronological
  # order. Sorted in Ruby rather than SQL so a preloaded association is read
  # from memory (the contracts list preloads :contract_periods and asks every
  # row for its current period) — which means a caller must PRELOAD the
  # periods, never `includes` them alongside a filter on contract_periods:
  # that collapses into one join and leaves the association holding only the
  # matching rows, and this would then answer about the wrong period. A period with no start date counts as
  # started — it was written before dates were required, and pretending it
  # lies in the future would hide it forever.
  def periods_by_time
    now = Time.current
    sorted = contract_periods.to_a.sort_by { |p| [ p.starts_at || p.created_at, p.created_at ] }
    sorted.partition { |p| (p.starts_at || p.created_at) <= now }
  end
end
