module Leads
  # Turns an answered request into a working account: the owner's login and
  # their company, ready to sign in. This is the ONLY way a gym gets onto
  # Fitora now — self-service signup is gone, so that every gym goes through
  # a conversation about what it costs them first.
  class Convert
    Result = Struct.new(:success?, :lead, :company, :owner, :password, :error, keyword_init: true)

    def self.call(lead:, admin:)
      new(lead: lead, admin: admin).call
    end

    def initialize(lead:, admin:)
      @lead = lead
      @admin = admin
    end

    def call
      return failure("This request has already been converted.") if lead.company_id.present?
      return failure("An account already exists for #{lead.email}.") if User.exists?(email: lead.email)

      password = SecureRandom.alphanumeric(12)
      owner = nil
      company = nil

      ActiveRecord::Base.transaction do
        owner = User.create!(
          first_name: first_name, last_name: last_name, email: lead.email,
          phone: lead.phone, password: password, role: :owner, locale: lead.locale
        )

        company = Company.create!(
          name: lead.gym_name, owner: owner, city: lead.city,
          phone: lead.phone, email: lead.email, locale: lead.locale
        )
        Role.seed_defaults_for(company)
        company.create_subscription!(status: :active, starts_at: Time.current, expires_at: 14.days.from_now)
        owner.update!(active_company: company)

        lead.update!(status: :converted, company: company, handled_by: admin, handled_at: Time.current)
      end

      Result.new(success?: true, lead: lead, company: company, owner: owner, password: password, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error: e.record.errors.full_messages.first)
    end

    private

    attr_reader :lead, :admin

    def failure(message)
      Result.new(success?: false, lead: lead, error: message)
    end

    # The form asks for one contact name; a User needs both halves.
    def first_name
      lead.contact_name.to_s.strip.split(/\s+/).first.presence || lead.contact_name
    end

    def last_name
      parts = lead.contact_name.to_s.strip.split(/\s+/)
      parts.length > 1 ? parts[1..].join(" ") : lead.gym_name
    end
  end
end
