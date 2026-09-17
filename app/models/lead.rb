# A demo or quote request from a gym that is not a customer yet.
class Lead < ApplicationRecord
  # A demo is "show me the app"; a quote is "what would it cost us" — the
  # same form, but they reach very different conversations.
  enum :kind, { demo: 0, quote: 1 }
  enum :status, { new_request: 0, contacted: 1, converted: 2, dropped: 3 }

  belongs_to :handled_by, class_name: "User", optional: true
  # Set once the request became a real account.
  belongs_to :company, optional: true

  before_validation { self.email = email.to_s.downcase.strip if email.present? }

  validates :contact_name, :gym_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :message, length: { maximum: 2000 }

  scope :recent, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: [ :new_request, :contacted ]) }
end
