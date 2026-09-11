FactoryBot.define do
  factory :contract do
    client
    contract_type
    company { contract_type.company }

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
      contract.contract_periods.create!(
        status: evaluator.status,
        starts_at: evaluator.starts_at,
        expires_at: evaluator.expires_at,
        discount: evaluator.discount,
        payment_status: evaluator.payment_status,
        remaining_bookings: evaluator.remaining_bookings
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
  end
end
