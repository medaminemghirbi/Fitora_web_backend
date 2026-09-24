module Subscriptions
  # The nightly sweep: closes access for every gym whose last invoice ran
  # out more than GRACE_DAYS ago.
  #
  # Idempotent by design — it only ever moves `active` from true to false,
  # and a gym already closed is skipped. Running it twice, or missing a
  # night and running it late, changes nothing about the outcome.
  class CloseUnpaid
    Result = Struct.new(:closed_count, keyword_init: true)

    def self.call = new.call

    def call
      closed = 0

      Subscription.where(active: true).includes(company: :invoices).find_each do |subscription|
        # "Ran out more than three days ago" is counted in the gym's days.
        next unless Time.use_zone(subscription.company.time_zone) { subscription.uncovered? }

        subscription.update!(active: false)
        closed += 1
      end

      Result.new(closed_count: closed)
    end
  end
end
