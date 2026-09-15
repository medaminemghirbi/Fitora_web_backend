FactoryBot.define do
  factory :subscription_price do
    sequence(:currency) { |n| CurrencyCatalog::CODES[n % CurrencyCatalog::CODES.size] }
    company_limit { 1 }
    monthly_cents { 16_500 }
  end
end
