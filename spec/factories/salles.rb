FactoryBot.define do
  factory :salle do
    location
    sequence(:name) { |n| "Salle #{n}" }
    capacity { 20 }
  end
end
