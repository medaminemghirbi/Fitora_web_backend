FactoryBot.define do
  factory :booking do
    client
    session
    status { :confirmed }
    amount { 20 }
    currency { "TND" }
    payment_status { :unpaid }
  end
end
