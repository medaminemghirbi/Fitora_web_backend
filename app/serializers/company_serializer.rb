class CompanySerializer
  def initialize(company)
    @company = company
  end

  def as_json(*)
    return nil if company.nil?

    {
      id: company.id,
      name: company.name,
      description: company.description,
      phone: company.phone,
      email: company.email,
      country: company.country,
      city: company.city,
      address: company.address,
      latitude: company.latitude,
      longitude: company.longitude,
      timezone: company.timezone,
      currency: company.currency,
      currency_symbol: company.currency_symbol,
      locale: company.locale,
      working_days: company.working_days,
      # Opening hours used to live on the site, then on the company itself;
      # they are settings now. Still "HH:MM" at the top level of the payload
      # — the storage moved, the API did not.
      business_hours_start: company.business_hours_start,
      business_hours_end: company.business_hours_end,
      active: company.active,
      slug: company.slug,
      primary_color: company.primary_color,
      logo_url: logo_url,
      # Every feature is included — the key list the owner's subscription
      # page renders as "what's included" (names/descriptions i18n'd
      # client-side as modules.<key>.*).
      included_modules: ModuleCatalog::KEYS,
      # How this company has configured the engine: which features it uses
      # and the rules it books by. The frontend reads this to decide what to
      # SHOW — never what to allow, which is `permissions`.
      settings: company.settings.to_h,

      monthly_subscription_cents: company.monthly_subscription_cents,
      annual_subscription_cents: company.annual_subscription_cents,
      annual_discount_percent: company.annual_discount_percent
      # What the company currently owes Fitora — set by hand by an admin,
    }
  end

  private

  attr_reader :company

  def logo_url
    return nil unless company.logo.attached?

    Rails.application.routes.url_helpers.rails_blob_path(company.logo, only_path: true)
  end
end
