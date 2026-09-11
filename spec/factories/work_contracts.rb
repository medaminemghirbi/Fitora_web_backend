FactoryBot.define do
  factory :work_contract do
    company
    staff_member { association :staff_member, company: company }
    work_contract_type { association :work_contract_type, company: company }
    job_title { "Coach" }
    starts_on { Date.new(2025, 1, 1) }
    gross_monthly_salary { 1500 }
    currency { "TND" }
    payment_method { :bank_transfer }
    paid_leave_days_per_year { 30 }
    status { :active }

    # A contract for a coach with no app login (staff_member stays nil).
    trait :for_coach do
      staff_member { nil }
      coach { association :coach, company: company }
    end
  end
end
