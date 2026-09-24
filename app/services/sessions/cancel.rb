module Sessions
  # Calling a session off, and everything that has to go with it.
  #
  # It used to be one status flip. Every booking on it stayed confirmed, so
  # the members kept a seat in a class that was not happening and never got
  # back the session it had cost them. Now each seat and each queue place is
  # cancelled through Bookings::Cancel, which gives back what was spent.
  # Staff are cancelling here, not the member, so no cancellation window
  # applies.
  class Cancel
    Result = ServiceResult.define(:session, :cancelled_bookings)

    def self.call(session:) = new(session: session).call

    def initialize(session:)
      @session = session
    end

    def call
      return Result.failure("This session is already cancelled.") if session.cancelled?

      cancelled = 0
      ActiveRecord::Base.transaction do
        # This very object, locked and cancelled: the bookings below reach
        # their session through it, and must see it called off, or freeing a
        # seat would promote the queue into a class that is not happening.
        session.lock!
        session.update!(status: :cancelled)

        # The queue first, so nobody in it is promoted into a seat on the way.
        (session.bookings.waitlisted.to_a + session.bookings.confirmed.to_a).each do |booking|
          Bookings::Cancel.call(booking: booking)
          tell_member(booking.client)
          cancelled += 1
        end
      end

      Result.ok(session: session, cancelled_bookings: cancelled)
    end

    private

    attr_reader :session

    def tell_member(client)
      Notifications::Push.call(
        recipient: client, company: session.company, kind: "session_cancelled", subject: session,
        dedup_key: "session_cancelled:#{session.id}:#{client.id}", url: "/member/bookings",
        data: { activity_name: session.activity.name, starts_at: session.starts_at.iso8601, gym_name: session.company.name }
      )
    end
  end
end
