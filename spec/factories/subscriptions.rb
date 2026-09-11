FactoryBot.define do
  factory :subscription do
    company
    status { :active }
    starts_at { 1.month.ago }
  end
end
