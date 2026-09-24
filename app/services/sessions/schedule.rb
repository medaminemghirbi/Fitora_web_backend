module Sessions
  # Putting a session on the calendar from the planning screen. An individual
  # session is scheduled *for* one member, who is booked into it in the same
  # transaction: if the booking cannot go through, the session never existed.
  # (It used to be created, then destroyed again by hand.)
  class Schedule
    Result = ServiceResult.define(:session)

    def self.call(activity:, attributes:, client: nil) = new(activity: activity, attributes: attributes, client: client).call

    def initialize(activity:, attributes:, client:)
      @activity = activity
      @attributes = attributes.to_h.symbolize_keys
      @client = client
    end

    def call
      outcome = nil

      ActiveRecord::Base.transaction do
        created = Sessions::Create.call(attributes: session_attributes)
        outcome = created
        raise ActiveRecord::Rollback unless created.success?

        if client
          booking = Bookings::Create.call(client: client, session: created.session)
          unless booking.success?
            outcome = booking
            raise ActiveRecord::Rollback
          end
        end
      end

      outcome.success? ? Result.ok(session: outcome.session) : Result.failure(outcome.error)
    end

    private

    attr_reader :activity, :attributes, :client

    # The activity's capacity unless one is given. No activity-level price to
    # fall back to — booking is settled against the member's contract — so a
    # blank price leaves the column default (0).
    def session_attributes
      attributes.merge(capacity: attributes[:capacity].presence || activity.capacity)
                .reject { |key, value| key == :price && value.blank? }
    end
  end
end
