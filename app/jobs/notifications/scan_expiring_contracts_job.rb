module Notifications
  # Daily: client contracts whose active period is within its warning window.
  class ScanExpiringContractsJob < ApplicationJob
    queue_as :default

    def perform
      ContractPeriod
        .expiring_soon(within: ContractPeriod::NOTIFY_WITHIN)
        .includes(contract: [ :company, :client, :contract_type ])
        .find_each { |period| notify(period) }
    end

    def notify(period)
      contract = period.contract
      owner = contract&.company&.owner
      return if owner.nil?

      Notifications::Push.call(
        recipient: owner,
        kind: "contract_expiring",
        subject: period,
        dedup_key: "contract_exp:#{period.id}:#{period.expires_at.to_date}",
        url: "/owner/clients/#{contract.client_id}",
        data: {
          client_name: contract.client&.full_name,
          contract_type: contract.contract_type&.name,
          expires_at: period.expires_at&.iso8601
        }
      )
    end
  end
end
