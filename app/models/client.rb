class Client < ApplicationRecord
  include PasswordResettable
  include EmailVerifiable

  belongs_to :company

  has_many :bookings, dependent: :destroy
  has_many :contracts, dependent: :destroy
  has_many :contract_periods, through: :contracts
  has_many :payments, dependent: :destroy

  # Mobile-app login for the client themselves — off by default (no
  # password_digest), turned on when the owner or a receptionist sets a
  # password from the client's profile (Api::V1::ClientsController#update).
  # Reuses the same has_secure_password/bcrypt setup as User, but optional:
  # a Client is still a valid business record with no login at all.
  has_secure_password validations: false

  before_validation { self.email = email.to_s.downcase.strip if email.present? }
  before_validation { self.joined_at ||= Time.current }

  validates :first_name, :last_name, :phone, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :email, presence: true, uniqueness: true, if: -> { password_digest.present? }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  scope :active, -> { where(active: true) }
  scope :search, ->(term) {
    return all if term.blank?

    sanitized = "%#{term.strip}%"
    where("first_name ILIKE :t OR last_name ILIKE :t OR phone ILIKE :t OR email ILIKE :t", t: sanitized)
  }

  def full_name
    "#{first_name} #{last_name}"
  end

  def login_enabled?
    password_digest.present?
  end

  # The Contract whose current term is still active — status/dates/price
  # live on ContractPeriod now, so this finds the contract by way of its
  # latest period rather than a flat column on Contract itself.
  def current_contract
    contracts.joins(:contract_periods).merge(ContractPeriod.currently_active).order("contract_periods.expires_at DESC").first
  end

  # What's still owed: unpaid bookings and contract periods, net of
  # any payments already recorded against them. Not a full accounting
  # ledger — just enough to flag a client with a balance due.
  def outstanding_balance
    owed = bookings.unpaid.sum(:amount) +
           contract_periods.unpaid.sum(:final_price)
    received = payments.paid.where.not(booking_id: nil).sum(:amount) +
               payments.paid.where.not(contract_period_id: nil).sum(:amount)
    [ owed - received, 0 ].max
  end

  def attendance_rate
    records = AttendanceRecord.joins(:booking).where(bookings: { client_id: id })
    total = records.count
    return nil if total.zero?

    (records.present.count.to_f / total * 100).round
  end
end
