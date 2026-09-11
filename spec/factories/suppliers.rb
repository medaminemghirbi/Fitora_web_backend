FactoryBot.define do
  factory :supplier do
    association :company
    sequence(:name) { |n| "Fournisseur #{n}" }
    category { "Équipement" }
    active { true }
  end
end
