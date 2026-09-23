module Contracts
  class Create
    Result = Struct.new(:success?, :contract, :payment, :error, keyword_init: true)

    def self.call(client:, contract_type:, activity:, created_by:, starts_on: Date.current, discount: 0,
                   collect_payment: false, payment_method: nil, payment_notes: nil)
      new(client: client, contract_type: contract_type, activity: activity, created_by: created_by, starts_on: starts_on,
          discount: discount, collect_payment: collect_payment, payment_method: payment_method, payment_notes: payment_notes).call
    end

    def initialize(client:, contract_type:, activity:, created_by:, starts_on:, discount:, collect_payment:, payment_method:, payment_notes:)
      @client = client
      @contract_type = contract_type
      @activity = activity
      @created_by = created_by
      @starts_on = starts_on
      @discount = discount
      @collect_payment = ActiveModel::Type::Boolean.new.cast(collect_payment)
      @payment_method = payment_method
      @payment_notes = payment_notes
    end

    def call
      contract = nil
      payment = nil

      # The price is the gym's, never the caller's: it's read from the plan's
      # pricing grid for this activity and frozen onto the period below, so a
      # client can't be subscribed at a price the frontend made up.
      base_price = contract_type.price_for(activity)
      if base_price.nil?
        # Says what to do, not only what is wrong: whoever hits this is at a
        # desk with someone waiting, and the fix is two screens away.
        return Result.new(success?: false, contract: nil, payment: nil,
                          error: "\"#{contract_type.name}\" has no price for #{activity.name}. " \
                                 "Set one in Abonnements → Formules before selling it.")
      end

      ActiveRecord::Base.transaction do
        # Date#to_time would resolve "starts_on" in the system's local
        # timezone rather than Time.zone, silently shifting the date by a day
        # whenever they differ — in_time_zone is the zone-aware conversion.
        starts_at = starts_on.in_time_zone

        # One Contract envelope per (client, plan, activity) — a second
        # purchase of the same plan for the same activity is a new period
        # under the same contract, not a new contract (see
        # Contract#current_period); a different activity under the same
        # plan is a genuinely separate contract.
        contract = Contract.find_or_create_by!(client: client, contract_type: contract_type, activity: activity) do |c|
          c.company = contract_type.company
          c.created_by = created_by
        end

        period = contract.contract_periods.create!(
          status: :active,
          starts_at: starts_at,
          expires_at: starts_at + contract_type.duration_days.days,
          remaining_bookings: contract_type.unlimited_bookings? ? nil : contract_type.booking_limit,
          discount: discount,
          base_price: base_price
        )
        # No part payments: collecting on creation records the full price.
        payment = record_payment(contract, period) if collect_payment
      end

      Result.new(success?: true, contract: contract, payment: payment, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, contract: nil, payment: nil, error: e.record.errors.full_messages.first)
    end

    private

    attr_reader :client, :contract_type, :activity, :created_by, :starts_on, :discount, :collect_payment, :payment_method, :payment_notes

    def record_payment(contract, period)
      payment = Payment.create!(
        client: client,
        company: contract_type.company,
        contract_period: period,
        amount: period.final_price,
        currency: contract_type.currency,
        payment_method: Payment::SELECTABLE_METHODS.include?(payment_method.to_s) ? payment_method : :cash,
        status: :paid,
        paid_at: Time.current,
        notes: payment_notes,
        created_by: created_by
      )
      period.update!(payment_status: :paid)
      payment
    end
  end
end
