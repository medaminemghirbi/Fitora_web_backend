# A gym's access to Fitora.
#
# `active` IS the access: every check reads it, nothing computes a date at
# read time. It is set false by a Fitora admin suspending the gym, and by
# the nightly sweep once the last invoice's period has run out and the three
# days of grace with it (Subscriptions::CloseUnpaid). Issuing an invoice
# sets it back to true.
#
# Everything else about paying lives in the invoices: "paid until" is the
# latest period_end, arrears are the periods with no invoice. The free trial
# is not a special case any more — it is simply the first period, given
# away, recorded like any other.
class Subscription < ApplicationRecord
  belongs_to :company

  BILLING_PERIODS = { monthly: 0, yearly: 1 }.freeze

  # How long a gym has to settle once the period it paid for has run out,
  # before access closes. Three days catches a transfer that crossed a
  # weekend, and is short enough not to be a free extra month.
  GRACE_DAYS = 3

  # Explicit attribute so the enum resolves even when the dev server's code
  # reloader runs before the schema cache has picked up the new column.
  attribute :billing_period, :integer
  enum :billing_period, BILLING_PERIODS

  validates :company_id, uniqueness: true

  scope :closed, -> { where(active: false) }

  delegate :invoices, to: :company

  # ---- what the invoices say ----------------------------------------------

  def latest_invoice
    invoices.newest_first.first
  end

  # The last day covered by an invoice, or nil when none was ever issued.
  def paid_through
    latest_invoice&.period_end
  end

  def current_period_paid?
    paid_through.present? && paid_through >= Date.current
  end

  # Past the paid period AND past the grace. What the nightly sweep acts on.
  def uncovered?
    paid_through.nil? || Date.current > paid_through + GRACE_DAYS
  end

  # Days left before the sweep closes access. nil when nothing is ticking.
  def days_before_lock
    return nil if current_period_paid? || paid_through.nil?

    [ (paid_through + GRACE_DAYS - Date.current).to_i, 0 ].max
  end

  # ---- why the door is shut, in two words ---------------------------------
  # Suspended is a decision; unpaid is everything else. There is no third
  # case: an expired trial IS an unpaid period whose first one was free.
  def lock_reason
    return nil if active?

    uncovered? ? :unpaid : :suspended
  end

  def locked?
    !active?
  end

  # The period an invoice would cover next: the day after the last one ends,
  # or today when there is no history.
  def next_period
    start = paid_through ? paid_through.next_day : Date.current
    finish = yearly? ? ((start >> 12) - 1) : ((start >> 1) - 1)
    start..finish
  end

  # Periods with no invoice behind them, times the tariff. Replaces the
  # figure that used to be typed in by hand and could contradict the history
  # beside it.
  def arrears_cents
    return 0 if paid_through.nil? || current_period_paid?

    months = ((Date.current.year * 12 + Date.current.month) - (paid_through.year * 12 + paid_through.month))
    periods = yearly? ? (months / 12.0).ceil : months
    [ periods, 0 ].max * (company.monthly_subscription_cents || 0) * (yearly? ? 12 : 1)
  end

  def suspend!
    update!(active: false)
  end

  def restore!
    update!(active: true)
  end
end
