class Coach < ApplicationRecord
  belongs_to :company

  has_many :coach_locations, dependent: :destroy
  has_many :locations, through: :coach_locations
  has_many :sessions, dependent: :nullify
  has_one :staff_member, dependent: :nullify

  validates :first_name, :last_name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :active, -> { where(active: true) }

  def full_name
    "#{first_name} #{last_name}"
  end

  # True on the person's birthday (day + month), any year.
  def birthday_today?(on: Date.current)
    birthdate.present? && birthdate.strftime("%m-%d") == on.strftime("%m-%d")
  end
end
