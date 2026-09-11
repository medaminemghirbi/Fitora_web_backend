module Payments
  class Refund
    Result = Struct.new(:success?, :error, keyword_init: true)

    def self.call(payment:)
      new(payment: payment).call
    end

    def initialize(payment:)
      @payment = payment
    end

    def call
      return Result.new(success?: false, error: "Only paid payments can be refunded.") unless payment.paid?

      payment.update!(status: :refunded)
      Result.new(success?: true, error: nil)
    end

    private

    attr_reader :payment
  end
end
