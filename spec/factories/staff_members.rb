FactoryBot.define do
  factory :staff_member do
    user { association :user, :staff }
    company
    role { :receptionist }
    active { true }
  end
end
