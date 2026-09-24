class User < ApplicationRecord
  has_secure_password
  include PasswordResettable
  include EmailVerifiable
  include TokenVersioned

  # A User is always staff: the Gymly-operator ("superadmin", manages every
  # company's SaaS subscription via /superadmin) or an in-gym account
  # (admin, or staff — the specific in-gym role lives on StaffMember).
  # Clients are business records the gym creates, never Users — see Client.
  enum :role, { admin: 0, staff: 1, superadmin: 2 }


  # An admin can run more than one company now (each a fully independent
  # tenant — its own clients, staff); company_limit gates how
  # many they may create (nil = unlimited), active_company is which one
  # their session is currently scoped to — see
  # Api::V1::BaseController#current_company and #switch.
  has_many :companies, foreign_key: :admin_id, inverse_of: :admin, dependent: :destroy
  belongs_to :active_company, class_name: "Company", optional: true
  has_one :staff_member, dependent: :destroy
  has_many :notifications, as: :recipient, dependent: :destroy

  before_validation { self.email = email.to_s.downcase.strip }

  validates :first_name, :last_name, presence: true
  validates :email, presence: true, uniqueness: true,
                     format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { new_record? || password.present? }
  validates :locale, inclusion: { in: %w[fr en ar] }
  # nil means unlimited — the only two capped tiers are 1 and 3 companies.
  validates :company_limit, inclusion: { in: [ 1, 3 ] }, allow_nil: true

  scope :active, -> { where(active: true) }

  def full_name
    "#{first_name} #{last_name}"
  end

  # Signed up, and the address not confirmed yet: nothing past sign-up
  # opens until it is. Admins only — see EmailVerifiable.
  def email_confirmation_pending?
    admin? && !email_verified?
  end

  def company_limit_reached?
    company_limit.present? && companies.count >= company_limit
  end

  # Moves this admin's active session to one of their OWN companies —
  # never lets them switch onto a company they don't own, since that's
  # exactly the cross-tenant boundary current_company exists to enforce.
  def switch_active_company!(company)
    return false unless companies.exists?(company.id)

    update!(active_company: company)
  end
end
