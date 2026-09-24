FactoryBot.define do
  factory :payment do
    client
    # The gym the money is owed to. A payment may only settle its own gym's
    # debt (Payment#payable_belongs_to_this_gym), so when a spec hands in
    # the period or booking, the gym is theirs; otherwise a period is sold
    # in this gym below.
    company do
      if contract_period then contract_period.contract.company
      elsif booking then booking.session.company
      else association(:company)
      end
    end
    contract_period { nil }
    booking { nil }
    amount { 89 }
    currency { "TND" }
    payment_method { :cash }
    status { :paid }
    paid_at { Time.current }

    after(:build) do |payment|
      next if payment.contract_period || payment.booking

      plan = create(:contract_type, company: payment.company)
      payment.contract_period = create(:contract, contract_type: plan, client: payment.client, payment_status: :paid).current_period
    end
  end
end
