class AdminCompanySerializer
  def initialize(company)
    @company = company
  end

  def as_json(*)
    {
      id: company.id,
      name: company.name,
      city: company.city,
      country: company.country,
      currency: company.currency,
      currency_symbol: company.currency_symbol,
      locale: company.locale,
      active: company.active,
      created_at: company.created_at,
      access_open: company.subscription&.active || false,
      owner: {
        id: company.owner.id,
        full_name: company.owner.full_name,
        email: company.owner.email,
        phone: company.owner.phone,
        # The tier governs the OWNER, not this one company — every company
        # under them shares it. nil = unlimited.
        company_limit: company.owner.company_limit,
        companies_count: company.owner.companies.count
      },
      subscription: SubscriptionSerializer.new(company.subscription).as_json,
      # Owed: periods with no invoice behind them, times the tariff. No
      # longer typed in by hand, so it cannot contradict the history.
      arrears_cents: company.subscription&.arrears_cents || 0,
      # What the gym is actually doing with Fitora. An activation decision
      # rests on this far more than on the subscription row: a gym with 180
      # members and a full week of sessions is a different conversation from
      # one that signed up and never came back.
      usage: usage,
      # The company's subscription price in its own currency — read-only
      # here; the admin edits prices per currency in the pricing screen.
      monthly_subscription_cents: company.monthly_subscription_cents,
      annual_subscription_cents: company.annual_subscription_cents,
      annual_discount_percent: company.annual_discount_percent,
      # Every feature is included for every company.
      included_modules: ModuleCatalog::KEYS
    }
  end

  private

  attr_reader :company

  def usage
    {
      clients: company.memberships.active.count,
      staff: company.staff_members.count,
      activities: company.activities.active.count,
      sessions_last_30_days: company.sessions.where(starts_at: 30.days.ago..).count,
      last_session_at: company.sessions.maximum(:starts_at)
    }
  end
end
