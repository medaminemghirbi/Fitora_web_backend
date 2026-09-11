require "rails_helper"

RSpec.describe Payroll::MonthlySheet do
  # March 2025: 31 days, 10 weekend days (5 Saturdays + 5 Sundays), so 21
  # working days under the company's default Monday-Friday schedule.
  it "computes worked/absence day counts and pro-rates the estimated gross for a staff member with unpaid leave" do
    company = create(:company)
    wc_type = create(:work_contract_type, company: company)
    staff = create(:staff_member, company: company)
    create(:work_contract, company: company, staff_member: staff, work_contract_type: wc_type,
                            gross_monthly_salary: 1500, starts_on: Date.new(2024, 1, 1), ends_on: nil)

    absence_type = create(:absence_type, company: company, paid: false, abbreviation: "CSS", name: "Congé sans solde")
    # 2025-03-03 (Mon) .. 2025-03-07 (Fri): 5 working days of unpaid leave.
    create(:leave_request, company: company, staff_member: staff, absence_type: absence_type, status: :approved,
                            starts_on: Date.new(2025, 3, 3), ends_on: Date.new(2025, 3, 7), days_count: 5)

    result = described_class.call(company: company, year: 2025, month: 3)

    expect(result[:month]).to eq("2025-03")
    expect(result[:month_label]).to eq("Mars 2025")
    expect(result[:working_days]).to eq(21)
    expect(result[:currency]).to eq(company.currency)

    emp = result[:employees].find { |e| e[:staff_member_id] == staff.id }
    expect(emp).to be_present
    expect(emp[:name]).to eq(staff.user.full_name)
    expect(emp[:role]).to eq("receptionist")
    expect(emp[:working_days]).to eq(21)
    expect(emp[:worked_days]).to eq(16)
    expect(emp[:paid_absence_days]).to eq(0)
    expect(emp[:unpaid_absence_days]).to eq(5)
    expect(emp[:absence_days]).to eq(5)
    expect(emp[:total_monthly_gross]).to eq(1500.0)
    expect(emp[:estimated_gross]).to eq(1142.857)
    expect(emp[:absences].size).to eq(1)
    expect(emp[:absences].first[:days]).to eq(5)
    expect(emp[:absences].first[:recorded_days]).to eq(5.0)
    expect(emp[:days].size).to eq(31)
  end

  it "includes a coach employed directly, with every working day counted as worked (coaches have no leave requests)" do
    company = create(:company)
    wc_type = create(:work_contract_type, company: company)
    coach = create(:coach, company: company)
    create(:work_contract, :for_coach, company: company, coach: coach, work_contract_type: wc_type,
                                        gross_monthly_salary: 1200, starts_on: Date.new(2025, 1, 1), ends_on: nil)

    result = described_class.call(company: company, year: 2025, month: 3)

    emp = result[:employees].find { |e| e[:coach_id] == coach.id }
    expect(emp).to be_present
    expect(emp[:staff_member_id]).to be_nil
    expect(emp[:role]).to eq("coach")
    expect(emp[:working_days]).to eq(21)
    expect(emp[:worked_days]).to eq(21)
    expect(emp[:absence_days]).to eq(0)
    expect(emp[:estimated_gross]).to eq(1200.0)
  end

  it "excludes an employee whose work contract does not overlap the requested month" do
    company = create(:company)
    wc_type = create(:work_contract_type, company: company)
    staff = create(:staff_member, company: company)
    create(:work_contract, company: company, staff_member: staff, work_contract_type: wc_type,
                            starts_on: Date.new(2024, 1, 1), ends_on: Date.new(2024, 12, 31), status: :ended)

    result = described_class.call(company: company, year: 2025, month: 3)

    expect(result[:employees]).to be_empty
  end

  it "returns no employees for a company with no work contracts at all" do
    company = create(:company)

    result = described_class.call(company: company, year: 2025, month: 3)

    expect(result[:employees]).to eq([])
    expect(result[:working_days]).to eq(21)
  end
end
