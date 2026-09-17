FactoryBot.define do
  factory :contract do
    client
    contract_type
    company { contract_type.company }
    # Defaults to the activity the plan is already priced for, so a contract
    # is sellable out of the box; an explicit `activity:` gets a grid row
    # created for it below.
    activity { contract_type.activities.first || create(:activity, company: contract_type.company) }

    transient do
      status { :active }
      starts_at { 1.day.ago }
      expires_at { 29.days.from_now }
      discount { 0 }
      payment_status { :unpaid }
      remaining_bookings { nil }
    end

    # Existing specs mostly reason about "the contract" as one flat
    # snapshot (status/dates/price) — that's really its current period, so
    # the factory builds one transparently from the same transient attrs.
    after(:create) do |contract, evaluator|
      row = contract.contract_type.contract_type_activities.find_or_create_by!(activity: contract.activity) { |r| r.price = 89 }

      contract.contract_periods.create!(
        status: evaluator.status,
        starts_at: evaluator.starts_at,
        expires_at: evaluator.expires_at,
        discount: evaluator.discount,
        payment_status: evaluator.payment_status,
        remaining_bookings: evaluator.remaining_bookings,
        base_price: row.price
      )
    end
  end

  factory :contract_period do
    contract
    status { :active }
    starts_at { 1.day.ago }
    expires_at { 29.days.from_now }
    discount { 0 }
    payment_status { :unpaid }
    base_price { contract.contract_type.price_for(contract.activity) || 89 }
  end
end
