module Contracts
  class Renew
    Result = Struct.new(:success?, :contract, :error, keyword_init: true)

    def self.call(contract:, created_by:)
      new(contract: contract, created_by: created_by).call
    end

    def initialize(contract:, created_by:)
      @contract = contract
      @created_by = created_by
    end

    # Adds a new ContractPeriod under the SAME contract — the client's
    # renewal history stays linked instead of scattering into disconnected
    # rows, while every existing period is left exactly as it was (the
    # product spec's "never touch contract history").
    def call
      plan = contract.contract_type
      current = contract.current_period
      starts_at = [ current&.expires_at, Time.current ].compact.max

      period = contract.contract_periods.create!(
        status: :active,
        starts_at: starts_at,
        expires_at: starts_at + plan.duration_days.days,
        remaining_bookings: plan.unlimited_bookings? ? nil : plan.booking_limit,
        discount: current&.discount || 0
      )

      Result.new(success?: true, contract: contract.reload, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, contract: nil, error: e.record.errors.full_messages.first)
    end

    private

    attr_reader :contract, :created_by
  end
end
