class ContractSerializer
  def initialize(contract)
    @contract = contract
  end

  def as_json(*)
    return nil if contract.nil?

    {
      id: contract.id,
      current_period_id: contract.current_period&.id,
      status: contract.status,
      starts_at: contract.starts_at,
      expires_at: contract.expires_at,
      remaining_bookings: contract.remaining_bookings,
      auto_renew: contract.auto_renew,
      discount: contract.discount,
      base_price: contract.current_period&.base_price,
      final_price: contract.final_price,
      payment_status: contract.payment_status,
      # No part payments — what's still owed is the full price when unpaid.
      amount_due: contract.unpaid? ? contract.final_price : 0,
      plan: ContractTypeSerializer.new(contract.contract_type).as_json,
      activity: { id: contract.activity.id, name: contract.activity.name, emoji: contract.activity.emoji },
      client: { id: contract.client.id, full_name: contract.client.full_name, phone: contract.client.phone }
    }
  end

  private

  attr_reader :contract
end
