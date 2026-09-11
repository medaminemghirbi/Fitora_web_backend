module Payments
  class Record
    Result = Struct.new(:success?, :payment, :error, keyword_init: true)

    def self.call(client:, company:, created_by:, amount:, payment_method:, currency: nil, notes: nil,
                   contract_period: nil, booking: nil)
      new(client: client, company: company, created_by: created_by, amount: amount, payment_method: payment_method,
          currency: currency, notes: notes, contract_period: contract_period, booking: booking).call
    end

    def initialize(client:, company:, created_by:, amount:, payment_method:, currency:, notes:, contract_period:, booking:)
      @client = client
      @company = company
      @created_by = created_by
      @payment_method = payment_method
      @currency = currency || company.currency
      @notes = notes
      @contract_period = contract_period
      @booking = booking
      # No part payments — "Encaisser" sends no amount and settles the payable
      # in full. An explicit amount is still honoured (e.g. an ad-hoc payment).
      @amount = amount.presence || contract_period&.final_price || booking&.amount
    end

    def call
      payment = nil

      ActiveRecord::Base.transaction do
        payment = Payment.create!(
          client: client, company: company, created_by: created_by,
          amount: amount, currency: currency, payment_method: payment_method, notes: notes,
          status: :paid, paid_at: Time.current,
          contract_period: contract_period, booking: booking
        )

        update_payable_status!
      end

      Result.new(success?: true, payment: payment, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, payment: nil, error: e.record.errors.full_messages.first)
    end

    private

    attr_reader :client, :company, :created_by, :amount, :payment_method, :currency, :notes, :contract_period, :booking

    # No part payments: a payable is paid once its recorded payments cover
    # its price, unpaid otherwise.
    def update_payable_status!
      if contract_period
        total_paid = contract_period.payments.reload.paid.sum(:amount)
        contract_period.update!(payment_status: total_paid >= contract_period.final_price.to_f ? :paid : :unpaid)
      elsif booking
        total_paid = booking.payments.reload.paid.sum(:amount)
        booking.update!(payment_status: total_paid >= booking.amount.to_f ? :paid : :unpaid)
      end
    end
  end
end
