module Clients
  # Erases a person from Gymly while keeping the gyms' books whole.
  #
  # Contracts, payments and past bookings stay — a gym's accounts cannot lose
  # rows because a member left — but nothing on them points at a
  # recognisable human any more: the name becomes a placeholder, the email,
  # phone and password go, every gym's copy of their details is wiped, every
  # upcoming booking is cancelled and every session ends.
  class Anonymise
    Result = ServiceResult.define(:client)

    PLACEHOLDER_FIRST_NAME = "Ancien".freeze
    PLACEHOLDER_LAST_NAME = "membre".freeze

    def self.call(client:) = new(client: client).call

    def initialize(client:)
      @client = client
    end

    def call
      ActiveRecord::Base.transaction do
        upcoming_bookings.find_each { |booking| Bookings::Cancel.call(booking: booking) }

        client.memberships.update_all( # rubocop:disable Rails/SkipsModelValidations
          Membership::PROFILE_FIELDS.index_with(nil).merge("notes" => nil, "active" => false, "updated_at" => Time.current)
        )

        # Past validation on purpose: a placeholder has no phone, and the
        # point is that it has nothing.
        client.update_columns( # rubocop:disable Rails/SkipsModelValidations
          first_name: PLACEHOLDER_FIRST_NAME, last_name: PLACEHOLDER_LAST_NAME,
          email: nil, phone: nil, password_digest: nil, active: false,
          email_verified_at: nil, email_verification_token_digest: nil, email_verification_sent_at: nil,
          reset_password_token_digest: nil, reset_password_sent_at: nil,
          invitation_token_digest: nil, invitation_sent_at: nil,
          token_version: client.token_version + 1, updated_at: Time.current
        )
      end

      Result.ok(client: client)
    end

    private

    attr_reader :client

    def upcoming_bookings
      client.bookings.where(status: %i[confirmed waitlisted]).joins(:session).where(sessions: { starts_at: Time.current.. })
    end
  end
end
