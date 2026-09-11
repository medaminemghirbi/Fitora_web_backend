module Notifications
  # Fired from ContractPeriod#after_commit when a period's expiry lands in the
  # warning window.
  class ContractExpiryChangedJob < ApplicationJob
    queue_as :default
    discard_on ActiveJob::DeserializationError

    def perform(period_id)
      period = ContractPeriod.includes(contract: [ :company, :client, :contract_type ]).find_by(id: period_id)
      return if period.nil? || !period.expiring_soon?

      ScanExpiringContractsJob.new.notify(period)
    end
  end
end
