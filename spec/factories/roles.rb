FactoryBot.define do
  factory :role do
    company
    sequence(:key) { |n| "role_#{n}" }
    sequence(:name) { |n| "Role #{n}" }
    permissions { %w[clients bookings] }
    builtin { false }
  end
end
