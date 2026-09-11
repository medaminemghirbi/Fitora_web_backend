FactoryBot.define do
  factory :payment do
    client
    company
    contract_period
    amount { 89 }
    currency { "TND" }
    payment_method { :cash }
    status { :paid }
    paid_at { Time.current }
  end
end
