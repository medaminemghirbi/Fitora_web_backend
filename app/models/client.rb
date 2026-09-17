class Client < ApplicationRecord
  include PasswordResettable
  include EmailVerifiable

  has_many :memberships, dependent: :destroy
  has_many :companies, through: :memberships

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
  validates :first_name, :last_name, :phone, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  # The email IS the person now: unique across the platform, so the same human
  # signing up at a second gym lands on their existing account instead of a
  # duplicate. A walk-in a gym recorded with no email is still valid.
  validates :email, uniqueness: { case_sensitive: false }, allow_blank: true
  validates :email, presence: true, if: -> { password_digest.present? }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  scope :active, -> { where(active: true) }
  scope :search, ->(term) {
    return all if term.blank?

    sanitized = "%#{term.strip}%"
    where("first_name ILIKE :t OR last_name ILIKE :t OR phone ILIKE :t OR email ILIKE :t", t: sanitized)
  }

  def self.find_by_email(email)
    return nil if email.blank?

    where("lower(email) = ?", email.to_s.downcase.strip).first
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def login_enabled?
    password_digest.present?
  end

  def membership_for(company)
    memberships.find_by(company_id: company.is_a?(Company) ? company.id : company)
  end

  # Joining is instant — there is nothing for the gym to approve. Called both
  # by the gym adding someone and by the person joining from the directory.
  def join!(company)
    memberships.find_or_create_by!(company_id: company.id)
  end

  # ---- per-gym views -------------------------------------------------------
  # A person now belongs to several gyms, so everything below takes the gym
  # being looked at. Passing nil means "across every gym" — only the person's
  # own account screens do that; a gym ALWAYS passes itself, otherwise one
  # gym would read another gym's contracts, money and attendance.

  def contracts_for(company)
    company ? contracts.where(company_id: company.id) : contracts
  end

  def bookings_for(company)
    return bookings if company.nil?

    bookings.joins(:session).where(sessions: { company_id: company.id })
  end

  def payments_for(company)
    company ? payments.where(company_id: company.id) : payments
  end

  # The Contract whose current term is still active — status/dates/price
  # live on ContractPeriod now, so this finds the contract by way of its
  # latest period rather than a flat column on Contract itself.
  def current_contract(company = nil)
    contracts_for(company)
      .joins(:contract_periods).merge(ContractPeriod.currently_active)
      .order("contract_periods.expires_at DESC").first
  end

  # What's still owed: unpaid bookings and contract periods, net of
  # any payments already recorded against them. Not a full accounting
  # ledger — just enough to flag a client with a balance due.
  def outstanding_balance(company = nil)
    periods = ContractPeriod.where(contract_id: contracts_for(company).select(:id))
    owed = bookings_for(company).unpaid.sum(:amount) + periods.unpaid.sum(:final_price)
    paid_scope = payments_for(company).paid
    received = paid_scope.where.not(booking_id: nil).sum(:amount) +
               paid_scope.where.not(contract_period_id: nil).sum(:amount)
    [ owed - received, 0 ].max
  end

  def attendance_rate(company = nil)
    records = AttendanceRecord.where(booking_id: bookings_for(company).select(:id))
    total = records.count
    return nil if total.zero?

    (records.present.count.to_f / total * 100).round
  end
end
