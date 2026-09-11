# The platform's monthly subscription price for one currency. A company
# sees its price in its own Company#currency (30 TND for a Tunisian gym,
# 30 EUR for a European one), not one fixed platform currency. Payment
# happens outside the app — the admin just sets the number the owner sees.
class SubscriptionPrice < ApplicationRecord
  # The currency every price is first set in — a currency seen for the
  # first time copies its starting price from here (see .for).
  REFERENCE_CURRENCY = "TND"
  DEFAULT_MONTHLY_CENTS = 16_500

  validates :currency, presence: true, inclusion: { in: CurrencyCatalog::CODES }, uniqueness: true
  validates :monthly_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # The row for a currency, creating it (seeded from REFERENCE_CURRENCY's
  # price, or DEFAULT_MONTHLY_CENTS when even that doesn't exist yet) so a
  # newly-seen currency never shows a price gap. The admin can then reprice
  # each currency independently.
  def self.for(currency)
    currency = currency.presence || REFERENCE_CURRENCY
    find_or_create_by!(currency: currency) do |row|
      row.monthly_cents = reference_monthly_cents
    end
  end

  def self.reference_monthly_cents
    find_by(currency: REFERENCE_CURRENCY)&.monthly_cents || DEFAULT_MONTHLY_CENTS
  end
  private_class_method :reference_monthly_cents
end
