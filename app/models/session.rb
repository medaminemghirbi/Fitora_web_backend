class Session < ApplicationRecord
  belongs_to :activity
  belongs_to :company
  belongs_to :coach, optional: true
  belongs_to :recurring_schedule, optional: true

  has_many :bookings, dependent: :destroy

  enum :status, { scheduled: 0, cancelled: 1, completed: 2 }

  validates :starts_at, :ends_at, :capacity, presence: true
  validates :capacity, numericality: { greater_than: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validate :activity_belongs_to_company
  validate :coach_belongs_to_company
  validate :ends_after_starts

  scope :upcoming, -> { where("starts_at >= ?", Time.current) }
  scope :for_date, ->(date) { where(starts_at: date.all_day) }

  def confirmed_bookings_count
    bookings.confirmed.count
  end

  # Confirmed + awaiting-payment bookings both hold a capacity slot, so a
  # session can't be oversold while a pay-per-booking checkout is in flight.
  def held_bookings_count
    bookings.held.count
  end

  def full?
    held_bookings_count >= capacity
  end

  private

  # A session can only run an activity its own gym offers.
  def activity_belongs_to_company
    return if activity.blank? || company.blank?

    # Compared as objects, not ids: on an unsaved record both ids are nil and
    # an id comparison would call a mismatch a match.
    errors.add(:activity, "must belong to this gym") if activity.company != company
  end

  # The site check this replaced was the only thing stopping another gym's
  # coach being scheduled here; the gym itself is the boundary now.
  def coach_belongs_to_company
    return if coach.blank? || company.blank?

    errors.add(:coach, "must belong to this gym") if coach.company != company
  end

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after the start time") if ends_at <= starts_at
  end
end
