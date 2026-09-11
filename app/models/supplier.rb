class Supplier < ApplicationRecord
  include HasPhoto

  belongs_to :company

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :active, -> { where(active: true) }
  scope :search, ->(term) {
    return all if term.blank?

    t = "%#{term.strip}%"
    where("name ILIKE :t OR category ILIKE :t OR contact_name ILIKE :t OR phone ILIKE :t OR email ILIKE :t", t: t)
  }
end
