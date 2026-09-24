class SuperadminCompanySerializer
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
      admin: {
        id: company.admin.id,
        full_name: company.admin.full_name,
        email: company.admin.email,
        phone: company.admin.phone,
        # The tier governs the ADMIN, not this one company — every company
        # under them shares it. nil = unlimited.
        company_limit: company.admin.company_limit,
        companies_count: company.admin.companies.count
      },
      subscription: SubscriptionSerializer.new(company.subscription).as_json,
      # Owed: periods with no invoice behind them, times the tariff. No
      # longer typed in by hand, so it cannot contradict the history.
      arrears_cents: company.subscription&.arrears_cents || 0,
      # What "payment received" would issue, read off the same methods
      # Invoices::Issue uses — so the button can say it before anyone clicks,
      # and a trial gym's next period is seen to start when the trial ends.
      next_invoice: next_invoice,
      # What the gym is actually doing with Gymly. An activation decision
      # rests on this far more than on the subscription row: a gym with 180
      # members and a full week of sessions is a different conversation from
      # one that signed up and never came back.
      usage: usage,
      # The company's subscription price in its own currency — read-only
      # here; the superadmin edits prices per currency in the pricing screen.
      monthly_subscription_cents: company.monthly_subscription_cents,
      annual_subscription_cents: company.annual_subscription_cents,
      annual_discount_percent: company.annual_discount_percent,
      # Every feature is included for every company.
      included_modules: ModuleCatalog::KEYS
    }
  end

  private

  attr_reader :company

  def next_invoice
    subscription = company.subscription
    return nil if subscription.nil?

    period = subscription.next_period
    { period_start: period.first, period_end: period.last, amount_cents: subscription.period_cents }
  end

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
