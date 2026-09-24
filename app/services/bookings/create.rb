module Bookings
  # Booking a member into a session.
  #
  # `by:` says who is asking, and it matters in two places: a member booking
  # from their own app is subject to the gym's rules about self-booking and
  # how far ahead the schedule opens, and the desk is not. Staff booking on
  # someone's behalf is the fallback for every case the rules did not
  # anticipate, so it stays unconstrained.
  class Create
    # `waitlisted` is true when the session was full and the gym runs a
    # queue: the booking exists, but it is a place in line, not a seat.
    Result = ServiceResult.define(:booking, :waitlisted)

    def self.call(client:, session:, by: :staff)
      new(client: client, session: session, by: by).call
    end

    def initialize(client:, session:, by: :staff)
      @client = client
      @session = session
      @by = by
    end

    def call
      booking = nil
      error = nil
      waitlisted = false

      ActiveRecord::Base.transaction do
        locked_session = Session.lock.find(session.id)
        activity = locked_session.activity
        company = activity.company

        if locked_session.cancelled?
          error = "This session has been cancelled."
        elsif locked_session.starts_at < Time.current
          error = "This session is no longer available."
        elsif (rule_error = member_booking_rules(company, locked_session))
          error = rule_error
        elsif locked_session.bookings.where(client_id: client.id).where.not(status: :cancelled).exists?
          error = "This client already has a booking for this session."
        elsif full?(locked_session) && !company.feature?(:waitlist)
          # No queue here: a full session is simply full, and saying so is
          # more use than telling them about a contract they would also need.
          error = "This session is full."
        else
          contract = find_contract_coverage(company: company, activity: activity)
          locked_period = contract && contract.contract_periods.lock.find(contract.current_period.id)

          if contract.nil? || !contract.usable_for?(activity: activity, period: locked_period)
            error = "This client needs an active contract to book this activity."
          elsif full?(locked_session)
            # Full, but this gym runs a queue — and a queue is still only for
            # members entitled to be in the session at all.
            booking = join_waitlist(locked_session, locked_period)
            waitlisted = true
          else
            booking = confirm_with_contract(locked_session, contract, locked_period)
          end
        end

        raise ActiveRecord::Rollback if error
      end

      if error
        Result.new(success?: false, booking: nil, error: error, waitlisted: false)
      else
        Result.new(success?: true, booking: booking, error: nil, waitlisted: waitlisted)
      end
    rescue ActiveRecord::RecordNotUnique
      Result.new(success?: false, booking: nil, error: "This client already has a booking for this session.", waitlisted: false)
    end

    private

    attr_reader :client, :session, :by

    def member? = by == :member

    def full?(locked_session)
      locked_session.held_bookings_count >= locked_session.capacity
    end

    # The rules that apply to a member booking themselves in, and to nobody
    # else. Returns nil when they are satisfied. The desk is never held to
    # these: staff booking on someone's behalf is the escape hatch for every
    # case a rule did not anticipate.
    def member_booking_rules(company, locked_session)
      return nil unless member?

      settings = company.settings

      return "Online booking is not available at this gym." unless settings.feature?(:online_booking)

      horizon = settings.booking_opens_days
      if horizon && locked_session.starts_at > horizon.days.from_now.end_of_day
        return "This session opens for booking #{horizon} days before it starts."
      end

      nil
    end

    def find_contract_coverage(company:, activity:)
      client.contracts.joins(:contract_periods).merge(ContractPeriod.currently_active)
            .where(company: company).distinct
            .find { |c| c.usable_for?(activity: activity) }
    end

    def confirm_with_contract(locked_session, contract, period)
      booking = locked_session.bookings.create!(
        client: client,
        status: :confirmed,
        amount: 0,
        currency: locked_session.activity.company.currency,
        payment_status: :paid,
        contract_period: period
      )

      contract.consume_booking!(period: period)

      booking
    end

    # A place in the queue, not a seat. No credit is spent: the member is
    # only charged a session if the seat actually comes free, which
    # Bookings::PromoteFromWaitlist handles when it does.
    def join_waitlist(locked_session, period)
      last = locked_session.bookings.queued.maximum(:waitlist_position).to_i

      locked_session.bookings.create!(
        client: client,
        status: :waitlisted,
        waitlist_position: last + 1,
        amount: 0,
        currency: locked_session.activity.company.currency,
        payment_status: :unpaid,
        contract_period: period
      )
    end
  end
end
