module Bookings
  # Cancelling a booking, and — where the gym has set one — honouring the
  # window it has to happen inside.
  #
  # `by:` says who is asking. A member cancelling from their own app is held
  # to the gym's cancellation window; the gym's own staff are not, because
  # the desk has to be able to fix things (a member who phoned in, a session
  # the coach called off) and a rule that stops them doing that is a rule
  # that gets worked around by deleting rows.
  class Cancel
    Result = ServiceResult.define(:promoted)

    def self.call(booking:, by: :staff)
      new(booking: booking, by: by).call
    end

    def initialize(booking:, by: :staff)
      @booking = booking
      @by = by
    end

    def call
      return Result.new(success?: false, error: "This booking is already cancelled.") if booking.cancelled?

      if member? && (message = too_late_to_cancel)
        return Result.new(success?: false, error: message)
      end

      promoted = nil
      # Only a seat spends a session. A place in the queue spent nothing
      # (Bookings::Create#join_waitlist), so cancelling it gives nothing back
      # — it used to, which handed out a free session per queue exit.
      held_a_seat = booking.confirmed?

      ActiveRecord::Base.transaction do
        booking.update!(status: :cancelled, waitlist_position: nil)
        if held_a_seat
          booking.contract_period&.contract&.restore_booking!
          # A seat freed in a session that is still on is the next in line's.
          promoted = Bookings::PromoteFromWaitlist.call(session: booking.session) unless booking.session.cancelled?
        end
      end

      Result.new(success?: true, error: nil, promoted: promoted)
    end

    private

    attr_reader :booking, :by

    def member? = by == :member

    # nil when the cancellation is allowed; otherwise what to tell them.
    def too_late_to_cancel
      hours = company&.settings&.cancellation_hours
      return nil if hours.nil? || hours.zero?

      starts_at = booking.session.starts_at
      return nil if starts_at.nil?
      return nil if Time.current <= starts_at - hours.hours

      if Time.current >= starts_at
        "This session has already started."
      else
        "Bookings can only be cancelled up to #{hours} #{'hour'.pluralize(hours)} before the session starts."
      end
    end

    def company
      booking.session&.company
    end
  end
end
