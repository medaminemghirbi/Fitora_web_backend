module Invoices
  # Records that money arrived: one invoice for the next period the gym has
  # not paid for, and access opened again.
  #
  # The amount is frozen here, at the tariff of the day. A price change later
  # must never rewrite a past invoice — the same rule ContractPeriod#base_price
  # follows for a member's own subscription.
  class Issue
    Result = Struct.new(:success?, :invoice, :error, keyword_init: true)

    def self.call(company:, issued_by:, notes: nil)
      new(company: company, issued_by: issued_by, notes: notes).call
    end

    def initialize(company:, issued_by:, notes:)
      @company = company
      @issued_by = issued_by
      @notes = notes
    end

    def call
      subscription = company.subscription
      return failure("This gym has no subscription.") if subscription.nil?

      invoice = nil
      period = subscription.next_period

      ActiveRecord::Base.transaction do
        invoice = Invoice.create!(
          company: company,
          number: Invoice.next_number,
          period_start: period.first,
          period_end: period.last,
          amount_cents: subscription.period_cents,
          currency: company.currency,
          billing_period: subscription.billing_period || :monthly,
          issued_at: Time.current,
          issued_by: issued_by,
          notes: notes
        )

        # Paying is what reopens the door; there is nothing else to do.
        subscription.update!(active: true)
      end

      Result.new(success?: true, invoice: invoice, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, invoice: nil, error: e.record.errors.full_messages.first)
    end

    private

    attr_reader :company, :issued_by, :notes

    def failure(message)
      Result.new(success?: false, invoice: nil, error: message)
    end
  end
end
