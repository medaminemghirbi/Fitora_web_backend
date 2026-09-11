FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { "Jane" }
    last_name { "Doe" }
    password { "password123" }
    role { :owner }
    locale { "fr" }

    trait :owner do
      role { :owner }
    end

    trait :admin do
      role { :admin }
    end

    trait :staff do
      role { :staff }
    end
  end
end
