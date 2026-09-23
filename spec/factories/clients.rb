FactoryBot.define do
  # A Client is the person, global to the platform. `company:` is kept as a
  # transient because almost every spec means "a member of this gym": it
  # creates the membership rather than a column on the person.
  factory :client do
    first_name { "Ahmed" }
    last_name { "Ben Ali" }
    sequence(:phone) { |n| "+216 20 #{100000 + n}" }
    sequence(:email) { |n| "client#{n}@example.com" }
    active { true }

    transient do
      company { nil }
      joined_at { 1.day.ago }
      notes { nil }
    end

    after(:create) do |client, evaluator|
      company = evaluator.company || create(:company)
      client.memberships.create!(
        company: company, joined_at: evaluator.joined_at,
        notes: evaluator.notes, active: client.active
      )
    end
  end

  factory :membership do
    client
    company
    joined_at { 1.day.ago }
    active { true }
  end
end
