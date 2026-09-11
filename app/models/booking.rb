class Booking < ApplicationRecord
  belongs_to :client
  belongs_to :session
  belongs_to :contract_period, optional: true

  has_many :payments, dependent: :nullify
  has_one :attendance_record, dependent: :destroy

  enum :status, { confirmed: 0, cancelled: 1, completed: 2, no_show: 3 }
  enum :payment_status, { unpaid: 0, paid: 1 }

  HELD_STATUSES = %w[confirmed].freeze

  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :client_id, uniqueness: {
                           scope: :session_id,
                           conditions: -> { where(status: HELD_STATUSES) },
                           message: "has already booked this session"
                         },
                         if: -> { HELD_STATUSES.include?(status) }

  scope :held, -> { where(status: HELD_STATUSES) }
end
