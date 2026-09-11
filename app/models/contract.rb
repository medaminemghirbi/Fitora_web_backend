class Contract < ApplicationRecord
  belongs_to :client
  belongs_to :contract_type
  belongs_to :company
  belongs_to :created_by, class_name: "User", optional: true

  has_many :contract_periods, dependent: :destroy
  has_many :payments, through: :contract_periods
  has_many :bookings, through: :contract_periods

  validates :client_id, uniqueness: { scope: :contract_type_id }

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

  def usable_for?(location:, activity:)
    return false unless current_period&.active? && (expires_at.nil? || expires_at >= Time.current)
    return false if contract_type.booking_limit.present? && !contract_type.unlimited_bookings? && remaining_bookings.to_i <= 0

    contract_type.grants_access_to?(location: location, activity: activity)
  end

  def consume_booking!
    return if contract_type.unlimited_bookings?
    return if current_period&.remaining_bookings.nil?

    current_period.decrement!(:remaining_bookings)
  end

  def restore_booking!
    return if contract_type.unlimited_bookings?
    return if current_period&.remaining_bookings.nil?

    current_period.increment!(:remaining_bookings)
  end
end
