require "rails_helper"

RSpec.describe Payroll::SheetPdf do
  def create_paid_staff_member(company, first_name:, salary: 1500)
    wc_type = create(:work_contract_type, company: company)
    user = create(:user, :staff, first_name: first_name, last_name: "Test")
    staff = create(:staff_member, company: company, user: user)
    create(:work_contract, company: company, staff_member: staff, work_contract_type: wc_type,
                            gross_monthly_salary: salary, starts_on: Date.new(2024, 1, 1))
    staff
  end

  it "renders a non-empty PDF with a %PDF header for a month with employees" do
    company = create(:company)
    create_paid_staff_member(company, first_name: "Amina")
    sheet = Payroll::MonthlySheet.call(company: company, year: 2025, month: 3)

    pdf_bytes = described_class.call(company: company, sheet: sheet)

    expect(pdf_bytes).to be_a(String)
    expect(pdf_bytes).not_to be_empty
    expect(pdf_bytes.byteslice(0, 4)).to eq("%PDF")
  end

  it "renders a placeholder page without raising when there are no employees" do
    company = create(:company)
    sheet = Payroll::MonthlySheet.call(company: company, year: 2025, month: 3)
    expect(sheet[:employees]).to be_empty

    pdf_bytes = described_class.call(company: company, sheet: sheet)

    expect(pdf_bytes.byteslice(0, 4)).to eq("%PDF")
  end

  it "produces a longer document as more employees are added" do
    company = create(:company)
    create_paid_staff_member(company, first_name: "Amina")
    sheet_one = Payroll::MonthlySheet.call(company: company, year: 2025, month: 3)
    pdf_one = described_class.call(company: company, sheet: sheet_one)

    create_paid_staff_member(company, first_name: "Youssef")
    sheet_two = Payroll::MonthlySheet.call(company: company, year: 2025, month: 3)
    pdf_two = described_class.call(company: company, sheet: sheet_two)

    expect(sheet_two[:employees].size).to eq(2)
    expect(pdf_two.bytesize).to be > pdf_one.bytesize
  end

  it "accepts an explicit employees subset instead of the full sheet" do
    company = create(:company)
    create_paid_staff_member(company, first_name: "Amina")
    create_paid_staff_member(company, first_name: "Youssef")
    sheet = Payroll::MonthlySheet.call(company: company, year: 2025, month: 3)
    expect(sheet[:employees].size).to eq(2)

    pdf_one_employee = described_class.call(company: company, sheet: sheet, employees: [ sheet[:employees].first ])
    pdf_all_employees = described_class.call(company: company, sheet: sheet)

    expect(pdf_one_employee.bytesize).to be < pdf_all_employees.bytesize
  end
end
