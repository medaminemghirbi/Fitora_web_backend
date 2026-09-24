module Companies
  # A gym opening on Gymly: the company, its built-in roles, its SaaS
  # subscription and the free trial — the first period, given away as an
  # invoice like any other, flagged so the gym reads as trying Gymly rather
  # than as on a tier it never chose. The admin's session moves onto it.
  class Open
    Result = ServiceResult.define(:company)

    def self.call(admin:, attributes:) = new(admin: admin, attributes: attributes).call

    def initialize(admin:, attributes:)
      @admin = admin
      @attributes = attributes
    end

    def call
      company = Company.new(attributes)
      company.admin = admin

      ActiveRecord::Base.transaction do
        company.save!
        # Built-in roles (admin, moderator, coach) — a company can
        # re-permission them or add its own from Settings.
        Role.seed_defaults_for(company)
        subscription = company.create_subscription!(active: true, billing_period: :monthly)
        issue_trial(company, subscription)
        admin.update!(active_company: company)
      end

      Result.ok(company: company)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record.errors.full_messages.first, company: company)
    end

    private

    attr_reader :admin, :attributes

    # Access is open because this invoice covers today.
    def issue_trial(company, subscription)
      Invoice.create!(
        company: company,
        number: Invoice.next_number,
        period_start: Date.current,
        period_end: Date.current + (Subscription::TRIAL_DAYS - 1),
        amount_cents: 0,
        trial: true,
        currency: company.currency,
        billing_period: subscription.billing_period,
        issued_at: Time.current,
        notes: "Période d'essai — #{Subscription::TRIAL_DAYS} jours offerts"
      )
    end
  end
end
