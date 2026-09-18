FactoryBot.define do
  factory :subscription do
    company
    active { true }
    billing_period { :monthly }

    # Access closed. Which of the two reasons it reports depends on whether
    # an invoice covers today — see Subscription#lock_reason.
    trait :closed do
      active { false }
    end
  end
end
