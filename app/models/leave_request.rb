class LeaveRequest < ApplicationRecord
  STATUSES = { pending: 0, approved: 1, rejected: 2 }.freeze

  belongs_to :company
  belongs_to :staff_member
  belongs_to :absence_type
  belongs_to :recorded_by, class_name: "User", optional: true

  enum :status, STATUSES, prefix: :status

  validates :starts_on, :ends_on, presence: true
  validates :days_count, numericality: { greater_than: 0 }
  validate :ends_on_after_starts_on
  validate :absence_type_belongs_to_company

  scope :in_year, ->(year) { where("EXTRACT(YEAR FROM starts_on) = ?", year) }
  scope :recent_first, -> { order(starts_on: :desc) }
  # Only approved leave of a "paid" absence type draws down the CP balance.
  scope :counts_against_balance, -> { status_approved.joins(:absence_type).where(absence_types: { paid: true }) }

  before_validation :default_days_count

  private

  # Working-day count between the two dates, based on the company's operating
  # days (Company#working_days) — a sensible default the owner can still
  # override (half days, public holidays, …).
  def default_days_count
    return if days_count.to_f.positive?
    return if starts_on.blank? || ends_on.blank? || ends_on < starts_on

    days = (starts_on..ends_on).to_a
    self.days_count =
      if company
        days.count { |day| company.working_day?(day) }
      else
        days.count { |day| !day.saturday? && !day.sunday? }
      end
  end

  def ends_on_after_starts_on
    return if starts_on.blank? || ends_on.blank?

    errors.add(:ends_on, "must be on or after the start date") if ends_on < starts_on
  end

  def absence_type_belongs_to_company
    return if absence_type.blank?

    errors.add(:absence_type, "must belong to the same company") if absence_type.company_id != company_id
  end
end
