FactoryBot.define do
  factory :company_module do
    company
    key { "fitness" }
    enabled { true }
  end
end
