FactoryBot.define do
  factory :session do
    activity
    location { activity.location }
    starts_at { 1.day.from_now.change(hour: 18) }
    ends_at { starts_at + 60.minutes }
    capacity { 10 }
    price { 20 }
    status { :scheduled }
  end
end
