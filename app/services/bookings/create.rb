module Bookings
  class Create
    Result = Struct.new(:success?, :booking, :error, keyword_init: true)

    def self.call(client:, session:)
      new(client: client, session: session).call
    end

    def initialize(client:, session:)
      @client = client
      @session = session
    end

    def call
      booking = nil
      error = nil

      ActiveRecord::Base.transaction do
        locked_session = Session.lock.find(session.id)
        activity = locked_session.activity
        company = activity.location.company

        if locked_session.cancelled?
          error = "This session has been cancelled."
        elsif locked_session.starts_at < Time.current
          error = "This session is no longer available."
        elsif locked_session.bookings.held.where(client_id: client.id).exists?
          error = "This client already has a booking for this session."
        elsif locked_session.held_bookings_count >= locked_session.capacity
          error = "This session is full."
        else
          contract = find_contract_coverage(company: company, location: locked_session.location, activity: activity)

          if contract
            locked_period = contract.contract_periods.lock.find(contract.current_period.id)

            if contract.usable_for?(location: locked_session.location, activity: activity, period: locked_period)
              booking = confirm_with_contract(locked_session, contract, locked_period)
            else
              error = "This client needs an active contract to book this activity."
            end
          else
            error = "This client needs an active contract to book this activity."
          end
        end

        raise ActiveRecord::Rollback if error
      end

      if error
        Result.new(success?: false, booking: nil, error: error)
      else
        Result.new(success?: true, booking: booking, error: nil)
      end
    rescue ActiveRecord::RecordNotUnique
      Result.new(success?: false, booking: nil, error: "This client already has a booking for this session.")
    end

    private

    attr_reader :client, :session

    def find_contract_coverage(company:, location:, activity:)
      client.contracts.joins(:contract_periods).merge(ContractPeriod.currently_active)
            .where(company: company).distinct
            .find { |c| c.usable_for?(location: location, activity: activity) }
    end

    def confirm_with_contract(locked_session, contract, period)
      booking = locked_session.bookings.create!(
        client: client,
        status: :confirmed,
        amount: 0,
        currency: locked_session.activity.location.company.currency,
        payment_status: :paid,
        contract_period: period
      )

      contract.consume_booking!(period: period)

      booking
    end
  end
end
