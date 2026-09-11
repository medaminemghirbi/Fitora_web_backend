class User < ApplicationRecord
  has_secure_password
  include PasswordResettable
  include EmailVerifiable

  # A User is always staff: the Fitora-operator ("admin", manages every
  # company's SaaS subscription via /admin) or an in-gym account
  # (owner, or staff — the specific in-gym role lives on StaffMember).
  # Clients are business records the gym creates, never Users — see Client.
  enum :role, { owner: 0, staff: 1, admin: 2 }

  has_one :company, foreign_key: :owner_id, inverse_of: :owner, dependent: :destroy
  has_one :staff_member, dependent: :destroy
  has_many :notifications, foreign_key: :recipient_id, inverse_of: :recipient, dependent: :destroy

  before_validation { self.email = email.to_s.downcase.strip }

  validates :first_name, :last_name, presence: true
  validates :email, presence: true, uniqueness: true,
                     format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { new_record? || password.present? }
  validates :locale, inclusion: { in: %w[fr en ar] }

  scope :active, -> { where(active: true) }

  def full_name
    "#{first_name} #{last_name}"
  end
end
