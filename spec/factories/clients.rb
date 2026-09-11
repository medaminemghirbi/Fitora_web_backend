FactoryBot.define do
  factory :client do
    company
    first_name { "Ahmed" }
    last_name { "Ben Ali" }
    sequence(:phone) { |n| "+216 20 #{100000 + n}" }
    sequence(:email) { |n| "client#{n}@example.com" }
    joined_at { 1.day.ago }
    active { true }
  end
end
