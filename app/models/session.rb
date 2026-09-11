class Session < ApplicationRecord
  belongs_to :activity
  belongs_to :location
  belongs_to :coach, optional: true
  belongs_to :recurring_schedule, optional: true

  has_many :bookings, dependent: :destroy

  enum :status, { scheduled: 0, cancelled: 1, completed: 2 }

  validates :starts_at, :ends_at, :capacity, presence: true
  validates :capacity, numericality: { greater_than: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validate :ends_after_starts
  validate :location_matches_activity
  validate :coach_assigned_to_location

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

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after the start time") if ends_at <= starts_at
  end

  def location_matches_activity
    return if activity.blank? || location.blank?

    errors.add(:location, "must match the activity's location") if activity.location_id != location_id
  end

  def coach_assigned_to_location
    return if coach.blank? || location.blank?

    unless coach.locations.exists?(id: location_id)
      errors.add(:coach, "is not assigned to this location")
    end
  end
end
