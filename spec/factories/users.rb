FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { "Jane" }
    last_name { "Doe" }
    password { "password123" }
    role { :owner }
    locale { "fr" }
    # Confirmed by default: an owner cannot reach anything past sign-up
    # without it (Api::V1::BaseController#require_confirmed_email!), and
    # almost no spec is about that.
    email_verified_at { Time.current }

    trait :unverified do
      email_verified_at { nil }
    end

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
