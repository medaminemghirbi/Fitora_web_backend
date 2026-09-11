FactoryBot.define do
  factory :coach do
    company
    first_name { "Coach" }
    sequence(:last_name) { |n| "Number#{n}" }
  end
end
