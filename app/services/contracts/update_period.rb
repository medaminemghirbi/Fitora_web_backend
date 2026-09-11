module Contracts
  # Edit the CURRENT period of a contract — start date, end date and (while
  # still unpaid) the discount. Changing the start date re-derives the end
  # date from the plan's billing period unless an explicit end date is given.
  class UpdatePeriod
    Result = Struct.new(:success?, :contract, :error, keyword_init: true)

    def self.call(contract:, starts_on: nil, expires_on: nil, discount: nil)
      new(contract: contract, starts_on: starts_on, expires_on: expires_on, discount: discount).call
    end

    def initialize(contract:, starts_on:, expires_on:, discount:)
      @contract = contract
      @starts_on = starts_on
      @expires_on = expires_on
      @discount = discount
    end

    def call
      period = contract.current_period
      return Result.new(success?: false, error: "No active subscription to edit") if period.nil?
      return Result.new(success?: false, error: "This subscription can no longer be edited") unless period.active? || period.pending?

      attrs = {}

      if starts_on.present?
        starts_at = Date.parse(starts_on.to_s).in_time_zone
        attrs[:starts_at] = starts_at
        attrs[:expires_at] = starts_at + contract.contract_type.duration_days.days
      end

      attrs[:expires_at] = Date.parse(expires_on.to_s).in_time_zone if expires_on.present?

      if discount.present?
        return Result.new(success?: false, error: "Discount can only change while the subscription is unpaid") unless period.unpaid?

        attrs[:discount] = discount.to_f
      end

      period.update!(attrs) if attrs.any?
      Result.new(success?: true, contract: contract.reload, error: nil)
    rescue ArgumentError
      Result.new(success?: false, error: "Invalid date")
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error: e.record.errors.full_messages.first)
    end

    private

    attr_reader :contract, :starts_on, :expires_on, :discount
  end
end
