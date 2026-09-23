# A person a gym trains. The record exists because staff created it, and the
# gym is what the person joined — there is no directory to find one in and no
# way to sign yourself up.
#
# They may still be given a way in, from their own file: an account the gym
# enables so they can read their gym's schedule, book a slot, cancel it, and
# see their own subscription and attendance. Off by default, and the gym's to
# grant — which is why there is no pairing key. A key exists to attach a
# device that has no account; these have one.
#
# The record is global rather than owned by one gym — the same person
# training at two gyms is one Client with two Memberships — so that a gym
# recording an existing email adopts the person instead of duplicating them.
# Each gym still only ever sees its own membership, contracts and payments.
class Client < ApplicationRecord
  include PasswordResettable
  include EmailVerifiable

  has_many :memberships, dependent: :destroy
  has_many :companies, through: :memberships

  has_many :bookings, dependent: :destroy
  has_many :contracts, dependent: :destroy
  has_many :contract_periods, through: :contracts
  has_many :payments, dependent: :destroy

  # Optional, unlike User's: a walk-in the gym wrote down is a perfectly
  # valid member with no login at all. Enabling one is what sets a password
  # (Api::V1::ClientsController#update).
  has_secure_password validations: false

  # A member with no email has NULL, never "".
  #
  # The guard here used to be `if email.present?`, which left an empty string
  # exactly as the form sent it. The unique index on lower(email) exempts
  # NULL but not "", so the first member saved without an email took the ""
  # slot and the second hit a duplicate-key 500 — a gym adding two members
  # off a phone number could not save the second.
  before_validation { self.email = email.to_s.downcase.strip.presence }
  validates :first_name, :last_name, :phone, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  # The email IS the person now: unique across the platform, so the same human
  # signing up at a second gym lands on their existing account instead of a
  # duplicate. A walk-in a gym recorded with no email is still valid.
  validates :email, uniqueness: { case_sensitive: false }, allow_blank: true
  # An account has to be reachable: the email is both the identifier and
  # where the invitation goes.
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

  # Joining is instant — there is nothing to approve. Called when a gym adds
  # someone, and when a gym records an email another gym already has.
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
