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
      # No part payments — a period is owed in full or not at all. Summed
      # over the current term AND any renewal queued behind it, so money
      # owed for a renewal does not vanish from the desk's screens.
      amount_due: contract.amount_due,
      # The period "Encaisser" settles: the oldest one still owed.
      payable_period_id: contract.payable_period&.id,
      plan: ContractTypeSerializer.new(contract.contract_type).as_json,
      # null for an all-access contract, which covers every activity its plan
      # covers rather than naming one. Read `all_access` to tell that apart
      # from missing data, and `activity_label` for something to show.
      activity: contract.activity && {
        id: contract.activity.id, name: contract.activity.name, emoji: contract.activity.emoji
      },
      # The renewals sold but not yet begun. A renewal made before the term
      # runs out never replaces it — both are kept, so both are shown.
      upcoming_periods: contract.upcoming_periods.map do |period|
        {
          id: period.id,
          starts_at: period.starts_at,
          expires_at: period.expires_at,
          final_price: period.final_price,
          payment_status: period.payment_status
        }
      end,
      all_access: contract.all_access?,
      activity_label: contract.activity_label,
      client: { id: contract.client.id, full_name: contract.client.full_name, phone: contract.client.phone }
    }
  end

  private

  attr_reader :contract
end
