class RecurringSchedule < ApplicationRecord
  # No-infinite-recurrence guardrail — generation never looks further ahead
  # than this, regardless of ends_on.
  GENERATION_HORIZON = 90.days

  belongs_to :activity
  belongs_to :company
  belongs_to :coach, optional: true

  has_many :sessions, dependent: :nullify

  enum :recurrence_type, { weekly: 0, daily: 1, monthly: 2 }

  validates :weekdays, presence: true
  validates :start_time, presence: true
  validates :starts_on, :ends_on, presence: true
  validate :activity_belongs_to_company
  validate :ends_after_starts
  validate :weekdays_are_valid

  scope :active, -> { where(active: true) }

  def generation_end_date
    [ ends_on, Date.current + GENERATION_HORIZON ].min
  end

  private

  # A recurring slot can only run an activity its own gym offers.
  def activity_belongs_to_company
    return if activity.blank? || company.blank?

    errors.add(:activity, "must belong to this gym") if activity.company != company
  end

  def ends_after_starts
    return if starts_on.blank? || ends_on.blank?

    errors.add(:ends_on, "must be after the start date") if ends_on < starts_on
  end

  def weekdays_are_valid
    return if weekdays.blank?

    errors.add(:weekdays, "must be between 0 (Sunday) and 6 (Saturday)") unless weekdays.all? { |d| (0..6).cover?(d) }
  end
end
