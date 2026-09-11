FactoryBot.define do
  factory :leave_request do
    company
    staff_member { association :staff_member, company: company }
    absence_type { association :absence_type, company: company, paid: true }
    status { :approved }
    starts_on { Date.new(2025, 3, 3) }
    ends_on { Date.new(2025, 3, 7) }
    days_count { 5 }
  end
end
