FactoryBot.define do
  factory :activity do
    company
    sequence(:name) { |n| "Activity #{n}" }
    session_format { :collective }
    duration { 60 }
    capacity { 10 }
  end
end
