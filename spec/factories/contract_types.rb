FactoryBot.define do
  factory :contract_type do
    company
    sequence(:name) { |n| "Plan #{n}" }
    billing_period { :monthly }
    unlimited_bookings { true }

    transient do
      # The price is no longer a column on the plan — it lives per activity
      # on the pricing grid. The factory keeps taking `price:` and puts it
      # there, on an activity it creates (or the one passed in), so specs
      # can still say `create(:contract_type, price: 100)` and mean it.
      price { 89 }
      activity { nil }
    end

    after(:create) do |plan, evaluator|
      activity = evaluator.activity || create(:activity, company: plan.company)
      plan.contract_type_activities.find_or_create_by!(activity: activity) { |row| row.price = evaluator.price }
    end
  end
end
