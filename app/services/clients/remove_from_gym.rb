module Clients
  # A gym letting a member go, and taking what it wrote about them with it.
  #
  # The membership — with this gym's notes and its copy of their details — is
  # deleted, and their upcoming bookings here are cancelled. The contracts and
  # payments stay: they are this gym's books. Someone still subscribed is
  # refused: the subscription is ended first, deliberately, not as a side
  # effect of a delete.
  #
  # If that leaves a person who belongs to no gym and never had a login of
  # their own, nobody is left to keep the record for, and it is anonymised.
  class RemoveFromGym
    Result = ServiceResult.define(:anonymised)

    def self.call(client:, company:) = new(client: client, company: company).call

    def initialize(client:, company:)
      @client = client
      @company = company
    end

    def call
      if client.current_contract(company)
        return Result.failure("This member still has an active subscription. End it before removing them.")
      end

      anonymised = false
      ActiveRecord::Base.transaction do
        upcoming_bookings.find_each { |booking| Bookings::Cancel.call(booking: booking) }
        client.membership_for(company)&.destroy!

        if client.memberships.reload.none? && !client.login_enabled?
          Clients::Anonymise.call(client: client)
          anonymised = true
        end
      end

      Result.ok(anonymised: anonymised)
    end

    private

    attr_reader :client, :company

    def upcoming_bookings
      client.bookings_for(company).where(status: %i[confirmed waitlisted]).where(sessions: { starts_at: Time.current.. })
    end
  end
end
