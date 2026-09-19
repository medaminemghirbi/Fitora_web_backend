class Booking < ApplicationRecord
  belongs_to :client
  belongs_to :session
  belongs_to :contract_period, optional: true

  has_many :payments, dependent: :nullify
  has_one :attendance_record, dependent: :destroy

  # 4 is the queue. 0..3 were already written into every existing row, so the
  # waitlist takes the next value rather than renumbering an enum in place.
  enum :status, { confirmed: 0, cancelled: 1, completed: 2, no_show: 3, waitlisted: 4 }
  enum :payment_status, { unpaid: 0, paid: 1 }

  # The statuses that occupy a seat. A waitlisted booking deliberately is not
  # one of them — that is the whole point of the queue.
  HELD_STATUSES = %w[confirmed].freeze

  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :client_id, uniqueness: {
                           scope: :session_id,
                           conditions: -> { where(status: HELD_STATUSES) },
                           message: "has already booked this session"
                         },
                         if: -> { HELD_STATUSES.include?(status) }

  validates :waitlist_position, numericality: { greater_than: 0 }, allow_nil: true
  # Mirrors the waitlist_position_iff_waitlisted check constraint, so the
  # failure is a validation error on a form rather than a 500 from Postgres.
  validate :waitlist_position_matches_status

  scope :held, -> { where(status: HELD_STATUSES) }
  scope :queued, -> { waitlisted.order(:waitlist_position) }

  private

  def waitlist_position_matches_status
    if waitlisted? && waitlist_position.blank?
      errors.add(:waitlist_position, "is required for a waitlisted booking")
    elsif !waitlisted? && waitlist_position.present?
      errors.add(:waitlist_position, "only applies to a waitlisted booking")
    end
  end
end
