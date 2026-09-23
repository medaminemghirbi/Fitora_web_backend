# One period of Fitora access, paid for and recorded.
#
# Payment happens off-app, so an invoice is not a demand — it is the proof
# that money arrived. A Fitora admin confirms it, the invoice is issued, and
# it lands in the gym's own account to download.
#
# Everything about the subscription that used to be stored is read from
# these: "paid until" is the latest period_end, arrears are the periods
# without a row.
class Invoice < ApplicationRecord
  belongs_to :company
  belongs_to :issued_by, class_name: "User", optional: true

  enum :billing_period, Subscription::BILLING_PERIODS, prefix: :covers

  validates :number, presence: true, uniqueness: true
  validates :period_start, :period_end, :issued_at, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validate :period_runs_forwards

  scope :chronological, -> { order(:period_start) }
  scope :newest_first, -> { order(period_start: :desc) }
  scope :covering, ->(date) { where(period_start: ..date).where(period_end: date..) }

  def amount
    amount_cents / 100.0
  end

  def covers?(date)
    (period_start..period_end).cover?(date)
  end

  # FIT-2026-0042: the year it was issued in, then a counter within that
  # year. Taken under a lock so two admins confirming at once cannot land on
  # the same number.
  def self.next_number(now: Time.current)
    year = now.year
    transaction do
      last = where("number LIKE ?", "FIT-#{year}-%").lock.order(:number).last
      sequence = last ? last.number.split("-").last.to_i + 1 : 1
      format("FIT-%<year>d-%<sequence>04d", year: year, sequence: sequence)
    end
  end

  private

  def period_runs_forwards
    return if period_start.blank? || period_end.blank?
    return if period_end >= period_start

    errors.add(:period_end, "must not be before the period starts")
  end
end
