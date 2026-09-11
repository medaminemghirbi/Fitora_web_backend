module Bookings
  class Cancel
    Result = Struct.new(:success?, :error, keyword_init: true)

    def self.call(booking:)
      new(booking: booking).call
    end

    def initialize(booking:)
      @booking = booking
    end

    def call
      return Result.new(success?: false, error: "This booking is already cancelled.") if booking.cancelled?

      ActiveRecord::Base.transaction do
        booking.update!(status: :cancelled)
        booking.contract_period&.contract&.restore_booking!
      end

      Result.new(success?: true, error: nil)
    end

    private

    attr_reader :booking
  end
end
