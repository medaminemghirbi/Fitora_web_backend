module Bookings
  # A seat has come free. Give it to whoever has waited longest.
  #
  # Only runs for a gym that turned the waitlist on: a queue nobody works
  # through is worse than a session that is honestly full, so the default is
  # to have no queue at all.
  #
  # Called inside the caller's transaction (see Bookings::Cancel), and takes
  # the same session lock the booking path does, so a seat freed while
  # another request is booking cannot be handed out twice.
  class PromoteFromWaitlist
    def self.call(session:)
      new(session: session).call
    end

    def initialize(session:)
      @session = session
    end

    # Returns the booking that was promoted, or nil when there was nobody
    # waiting, no room for them, or no waitlist at this gym.
    def call
      return nil unless session&.company&.feature?(:waitlist)

      locked_session = Session.lock.find(session.id)
      return nil if locked_session.held_bookings_count >= locked_session.capacity

      next_up = locked_session.bookings.queued.first
      return nil if next_up.nil?

      next_up.update!(status: :confirmed, waitlist_position: nil)
      next_up.contract_period&.contract&.consume_booking!(period: next_up.contract_period)
      resequence(locked_session)

      next_up
    end

    private

    attr_reader :session

    # Close the gap the promotion left, so positions stay 1, 2, 3 rather
    # than drifting into 2, 5, 9 as people come and go.
    def resequence(locked_session)
      locked_session.bookings.queued.each_with_index do |booking, index|
        position = index + 1
        booking.update_columns(waitlist_position: position) if booking.waitlist_position != position
      end
    end
  end
end
