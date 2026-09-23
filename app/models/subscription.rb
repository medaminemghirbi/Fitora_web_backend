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
# is the first period, given away: an invoice like any other, flagged
# `trial` so the gym is shown as trying Fitora rather than as already on a
# tier it never chose.
class Subscription < ApplicationRecord
  belongs_to :company

  BILLING_PERIODS = { monthly: 0, yearly: 1 }.freeze

  # How long a gym has to settle once the period it paid for has run out,
  # before access closes. Three days catches a transfer that crossed a
  # weekend, and is short enough not to be a free extra month.
  GRACE_DAYS = 3

  # What signup gives away. Everything is included; the salle cap is still
  # the owner's (User#company_limit).
  TRIAL_DAYS = 14

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

  # Nothing has been paid yet: the last period on record is the free one,
  # running or run out.
  def trial?
    latest_invoice&.trial? || false
  end

  # Free days left, today included. nil outside a trial.
  def trial_days_left
    return nil unless trial?

    [ (paid_through - Date.current).to_i + 1, 0 ].max
  end

  # The grace is for a payment in flight. A trial has none, so it closes the
  # day after it ends.
  def grace_days
    trial? ? 0 : GRACE_DAYS
  end

  # Past the paid period AND past the grace. What the nightly sweep acts on.
  def uncovered?
    paid_through.nil? || Date.current > paid_through + grace_days
  end

  # Days left before the sweep closes access. nil when nothing is ticking.
  def days_before_lock
    return nil if current_period_paid? || paid_through.nil?

    [ (paid_through + grace_days - Date.current).to_i, 0 ].max
  end

  # ---- why the door is shut, in two words ---------------------------------
  # Suspended is a decision; unpaid is everything else. An expired trial is
  # unpaid too — `trial?` is what lets a screen word it as the end of the
  # free days rather than a missed payment.
  def lock_reason
    return nil if active?

    uncovered? ? :unpaid : :suspended
  end

  def locked?
    !active?
  end

  # The period an invoice would cover next: the day after the last one ends,
  # or today when there is no history. A first payment after the trial ran
  # out starts today — the days in between were closed, not owed.
  def next_period
    start = paid_through ? paid_through.next_day : Date.current
    start = [ start, Date.current ].max if trial?
    finish = yearly? ? ((start >> 12) - 1) : ((start >> 1) - 1)
    start..finish
  end

  # Periods with no invoice behind them, times the tariff. Replaces the
  # figure that used to be typed in by hand and could contradict the history
  # beside it.
  def arrears_cents
    return 0 if current_period_paid?
    # A trial that ran out was never a promise to pay.
    return 0 if trial?

    # Never invoiced at all: the period in progress is owed. Reporting zero
    # here read as "nothing due" right beside "paid through: never".
    return period_cents if paid_through.nil?

    months = ((Date.current.year * 12 + Date.current.month) - (paid_through.year * 12 + paid_through.month))
    periods = yearly? ? (months / 12.0).ceil : months
    [ periods, 1 ].max * period_cents
  end

  def period_cents
    monthly = company.monthly_subscription_cents.to_i
    yearly? ? company.annual_subscription_cents.to_i : monthly
  end

  def suspend!
    update!(active: false)
  end

  def restore!
    update!(active: true)
  end
end
