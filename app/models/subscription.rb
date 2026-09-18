class Subscription < ApplicationRecord
  belongs_to :company

  BILLING_PERIODS = { monthly: 0, yearly: 1 }.freeze

  # How long a gym has to settle once the period it paid for has run out,
  # before access closes. Three days is enough to catch a transfer that
  # crossed a weekend, and short enough that it is not a free extra month.
  GRACE_DAYS = 3

  enum :status, { active: 0, inactive: 1, expired: 2, cancelled: 3 }
  # Explicit attribute so the enum resolves even when the dev server's code
  # reloader runs before the schema cache has picked up the new column.
  attribute :billing_period, :integer
  enum :billing_period, BILLING_PERIODS

  validates :starts_at, presence: true
  validates :company_id, uniqueness: true
  validates :upgrade_requested_period, inclusion: { in: BILLING_PERIODS.keys.map(&:to_s) }, allow_nil: true

  # No plans, no tiers — this is just the company's access status with
  # Fitora, set by hand by a platform admin (Api::V1::Admin::CompaniesController#update_subscription).
  # expires_at doubles as the free-trial deadline: set to 14 days out at
  # signup (see Api::V1::CompaniesController#create), and cleared to nil
  # the moment an admin manually grants ongoing access — nil means "not on
  # a ticking clock." Once it passes, or the moment status is anything but
  # active (admin marks it inactive/expired/cancelled),
  # Api::V1::BaseController locks every account in the company except the owner.
  # Why access is closed, or nil when it is open. One reason at a time, in
  # the order they override each other: an admin's own decision first, then
  # a deadline that has passed, then money.
  def lock_reason
    return :suspended unless active?
    return (on_trial? ? :trial_expired : :term_ended) if expires_at.present? && expires_at <= Time.current
    return :payment_overdue if payment_overdue?

    nil
  end

  def locked?
    lock_reason.present?
  end

  # ---- paying, month by month ---------------------------------------------
  # paid_through is the last day covered by what the gym has paid. A trial
  # is not part of this: it has its own deadline in expires_at.

  # The boolean an admin thinks in: is the period we are in settled?
  def current_period_paid?
    paid_through.present? && paid_through >= Date.current
  end

  def payment_overdue?
    return false if on_trial? || !active?

    paid_through.nil? || Date.current > paid_through + GRACE_DAYS
  end

  # Days left before access closes, once the paid period has run out. nil
  # when nothing is ticking; 0 means it closes today.
  def days_before_lock
    return nil if on_trial? || !active? || paid_through.nil? || current_period_paid?

    [ (paid_through + GRACE_DAYS - Date.current).to_i, 0 ].max
  end

  # Records one period's payment: coverage continues from wherever it
  # currently ends, never from today.
  #
  # That distinction matters for a gym that skipped a month. Paying now
  # covers the month it missed, and it stays overdue for the one in
  # progress — which is true, and is what an admin needs to see. Restarting
  # the clock from today would quietly write off the arrears instead.
  # Paying several months at once is several calls, and they stack.
  def record_payment!
    from = paid_through || Date.current.prev_day
    update!(paid_through: yearly? ? (from >> 12) : (from >> 1))
  end

  # An admin correcting a mistake — a payment recorded that never arrived.
  # Reverses exactly one period; if that leaves the gym overdue, it is
  # overdue, and the date says so rather than being tidied away.
  def undo_payment!
    return if paid_through.nil?

    update!(paid_through: yearly? ? (paid_through << 12) : (paid_through << 1))
  end

  def days_remaining
    return nil if expires_at.blank?

    [ (expires_at.to_date - Date.current).to_i, 0 ].max
  end

  # True until an admin activates a real (paid) subscription by setting a
  # billing period — everything before that is the free trial.
  def on_trial?
    billing_period.blank?
  end

  # The ones Fitora has to answer. Oldest first: whoever has been waiting
  # longest is the one being kept waiting.
  scope :awaiting_activation, -> { where.not(upgrade_requested_at: nil).order(:upgrade_requested_at) }

  def upgrade_requested?
    upgrade_requested_at.present?
  end

  # The owner asks Fitora to activate their subscription (payment off-app),
  # optionally flagging a preferred billing period for the admin.
  def request_upgrade!(period: nil)
    period = period.to_s if period.present?
    period = nil unless BILLING_PERIODS.key?(period&.to_sym)
    update!(upgrade_requested_at: Time.current, upgrade_requested_period: period)
  end

  def cancel_upgrade_request!
    update!(upgrade_requested_at: nil, upgrade_requested_period: nil)
  end
end
