FactoryBot.define do
  factory :absence_type do
    company
    sequence(:name) { |n| "Absence #{n}" }
    sequence(:abbreviation) { |n| "A#{n}" }
    paid { true }
    active { true }
  end
end
