FactoryBot.define do
  factory :invoice do
    company
    sequence(:number) { |n| format("FIT-2026-%04d", n) }
    period_start { Date.current.beginning_of_month }
    period_end { Date.current.end_of_month }
    amount_cents { 9_900 }
    currency { "TND" }
    billing_period { :monthly }
    issued_at { Time.current }

    # Covers today and the rest of this month — the ordinary "paid up" case.
    trait :current do
      period_start { Date.current.beginning_of_month }
      period_end { Date.current.end_of_month }
    end

    # Ran out long enough ago that the grace has passed too.
    trait :lapsed do
      period_start { Date.current - 40 }
      period_end { Date.current - 10 }
    end
  end
end
