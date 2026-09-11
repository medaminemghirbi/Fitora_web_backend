FactoryBot.define do
  factory :location do
    company
    sequence(:name) { |n| "Location #{n}" }
    timezone { "Africa/Tunis" }
  end
end
