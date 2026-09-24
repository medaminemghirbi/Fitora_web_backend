# The admin's page about their own Gymly access: whether it is open and
# until when, every invoice, what the tiers cost in their currency, and where
# to send the money.
class SubscriptionStatusSerializer
  def initialize(company:, admin:)
    @company = company
    @admin = admin
  end

  def as_json(*)
    subscription = company&.subscription

    {
      subscription: SubscriptionSerializer.new(subscription).as_json,
      invoices: company ? company.invoices.newest_first.map { |i| InvoiceSerializer.new(i).as_json } : [],
      clients_used: company&.clients&.count || 0,
      staff_used: company&.staff_members&.count || 0,
      currency: company&.currency,
      currency_symbol: company&.currency_symbol,
      monthly_subscription_cents: company&.monthly_subscription_cents || 0,
      annual_subscription_cents: company&.annual_subscription_cents || 0,
      annual_discount_percent: company&.annual_discount_percent || 0,
      arrears_cents: subscription&.arrears_cents || 0,
      trial_days: Subscription::TRIAL_DAYS,
      included_modules: ModuleCatalog::KEYS,
      # How many companies this admin may run, and what each tier costs in
      # their currency — the full comparison, not just their own tier.
      company_limit: admin.company_limit,
      companies_count: admin.companies.count,
      company_limit_reached: admin.company_limit_reached?,
      company_tiers: company_tiers(company&.currency),
      # Where to send the money. nil when no RIB is configured, and the page
      # falls back to the generic wording.
      payout: PayoutAccount.current&.as_json(company: company)
    }
  end

  private

  attr_reader :company, :admin

  def company_tiers(currency)
    return [] if currency.blank?

    discount = PlatformSetting.current.annual_discount_percent
    SubscriptionPrice::TIERS.map do |tier|
      price = SubscriptionPrice.for(currency, company_limit: tier)
      {
        company_limit: price.unlimited? ? nil : tier,
        monthly_cents: price.monthly_cents,
        annual_cents: (price.monthly_cents * 12 * (100 - discount) / 100.0).round
      }
    end
  end
end
