class Payment < ApplicationRecord
  belongs_to :client
  belongs_to :company
  belongs_to :contract_period, optional: true
  belongs_to :booking, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  enum :status, { paid: 0, partial: 1, refunded: 2, cancelled: 3 }
  # `card` is retained so historical rows keep deserialising, but card
  # payments are out of scope for now — SELECTABLE_METHODS is what any new
  # or edited payment may use. See Contracts::Create / Payments::Record.
  enum :payment_method, { cash: 0, card: 1, bank_transfer: 2, other: 3 }
  SELECTABLE_METHODS = %w[cash bank_transfer other].freeze

  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :payment_method, inclusion: { in: SELECTABLE_METHODS },
                             if: :will_save_change_to_payment_method?
  validate :linked_to_exactly_one_payable

  scope :recent, -> { order(created_at: :desc) }

  private

  def linked_to_exactly_one_payable
    links = [ contract_period_id, booking_id ].compact
    errors.add(:base, "must be linked to a contract or booking") if links.empty?
  end
end
