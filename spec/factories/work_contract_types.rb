FactoryBot.define do
  factory :work_contract_type do
    company
    sequence(:name) { |n| "Contract type #{n}" }
    sequence(:abbreviation) { |n| "T#{n}" }
    fixed_term { false }
    active { true }
  end
end
