FactoryBot.define do
  factory :recurring_schedule do
    activity
    location { activity.location }
    company { activity.location.company }
    weekdays { [ 1 ] } # Monday
    start_time { "18:00" }
    recurrence_type { :weekly }
    starts_on { Date.current }
    ends_on { 30.days.from_now.to_date }
    active { true }
  end
end
