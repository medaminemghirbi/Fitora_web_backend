# The platform's monthly subscription price for one currency AND one
# company-limit tier — an owner's tier caps how many companies they may
# run (see User#company_limit), and each tier is priced independently.
# A company sees its price in its own Company#currency (30 TND for a
# Tunisian gym, 30 EUR for a European one), not one fixed platform
# currency. Payment happens outside the app — the admin just sets the
# number the owner sees.
class SubscriptionPrice < ApplicationRecord
  # The currency every tier is first priced in — a (currency, tier)
  # combination seen for the first time copies its starting price from
  # here (see .for).
  REFERENCE_CURRENCY = "TND"
  DEFAULT_MONTHLY_CENTS = 16_500

  # UNLIMITED is a sentinel (0), not literal NULL: Postgres doesn't treat
  # NULL as equal to NULL for uniqueness, so a plain unique index on
  # [currency, company_limit] couldn't rely on NULL to mean "unlimited"
  # without risking duplicate rows. User#company_limit still uses nil for
  # unlimited on its own side — normalize_tier is the one place that gap
  # is bridged.
  UNLIMITED = 0
  TIERS = [ 1, 3, UNLIMITED ].freeze

  # Seed multiplier for a (currency, tier) combination that's never been
  # priced anywhere yet — a starting point only; the admin reprices each
  # one independently from there.
  DEFAULT_MULTIPLIERS = { 1 => 1.0, 3 => 2.5, UNLIMITED => 5.0 }.freeze

  validates :currency, presence: true, inclusion: { in: CurrencyCatalog::CODES }
  validates :currency, uniqueness: { scope: :company_limit }
  validates :company_limit, inclusion: { in: TIERS }
  validates :monthly_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:company_limit) }

  # The row for a (currency, tier) pair, creating it — seeded from that
  # same tier's REFERENCE_CURRENCY price, or a multiplier off
  # DEFAULT_MONTHLY_CENTS when even that doesn't exist yet — so a newly-
  # seen currency or tier never shows a price gap.
  def self.for(currency, company_limit:)
    currency = currency.presence || REFERENCE_CURRENCY
    tier = normalize_tier(company_limit)

    find_or_create_by!(currency: currency, company_limit: tier) do |row|
      row.monthly_cents = seed_monthly_cents(tier)
    end
  end

  # User#company_limit uses nil for "unlimited"; this column uses the
  # UNLIMITED sentinel — bridge the two, and fall back to the base tier
  # for anything else unrecognized rather than raising on bad input.
  def self.normalize_tier(company_limit)
    value = company_limit.nil? ? UNLIMITED : company_limit.to_i
    TIERS.include?(value) ? value : 1
  end

  def self.seed_monthly_cents(tier)
    find_by(currency: REFERENCE_CURRENCY, company_limit: tier)&.monthly_cents ||
      (DEFAULT_MONTHLY_CENTS * DEFAULT_MULTIPLIERS.fetch(tier, 1.0)).round
  end
  private_class_method :seed_monthly_cents

  def unlimited?
    company_limit == UNLIMITED
  end
end
