FactoryBot.define do
  factory :space do
    company
    sequence(:name) { |n| "Studio #{n}" }
    kind { "studio" }
    capacity { nil }
    active { true }
  end

  factory :activity_space do
    activity
    space { create(:space, company: activity.company) }
  end
end
