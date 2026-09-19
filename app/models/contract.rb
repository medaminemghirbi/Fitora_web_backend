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
  # remaining sessions) is really about their CURRENT term — the latest
  # period — so it's delegated rather than stored flat on Contract itself.
  # Not memoized: #reload doesn't know to clear a plain ivar, and this
  # isn't a hot enough path to be worth the staleness risk.
  delegate :status, :starts_at, :expires_at, :remaining_bookings, :discount, :final_price, :payment_status,
           :pending?, :active?, :expired?, :cancelled?, :unpaid?, :paid?,
           to: :current_period, allow_nil: true

  def current_period
    contract_periods.order(starts_at: :desc, created_at: :desc).first
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
end
