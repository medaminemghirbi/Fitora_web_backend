require "rails_helper"

RSpec.describe "Api::V1::Owner::Payroll", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }
  let!(:staff) { create(:staff_member, company: company, role: :receptionist) }
  let!(:cdi) { create(:work_contract_type, company: company, abbreviation: "CDI") }
  let!(:cp) { create(:absence_type, company: company, abbreviation: "CP", paid: true) }
  let!(:css) { create(:absence_type, company: company, abbreviation: "CSS", paid: false) }

  before do
    create(:work_contract, company: company, staff_member: staff, work_contract_type: cdi,
           starts_on: Date.new(2025, 1, 1), gross_monthly_salary: 2000, status: :active)
  end

  it "builds the monthly sheet with a work/absence grid" do
    # Aug 2026: 21 working days. CP Aug 4–7 (4 working days, paid), CSS Aug 10–11 (2, unpaid)
    create(:leave_request, company: company, staff_member: staff, absence_type: cp, status: :approved,
           starts_on: Date.new(2026, 8, 4), ends_on: Date.new(2026, 8, 7), days_count: 4)
    create(:leave_request, company: company, staff_member: staff, absence_type: css, status: :approved,
           starts_on: Date.new(2026, 8, 10), ends_on: Date.new(2026, 8, 11), days_count: 2)

    get "/api/v1/owner/payroll", params: { month: "2026-08" }, headers: auth_headers(owner)

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["working_days"]).to eq(21)
    emp = body["employees"].first
    expect(emp["worked_days"]).to eq(15)
    expect(emp["paid_absence_days"]).to eq(4)
    expect(emp["unpaid_absence_days"]).to eq(2)
    expect(emp["days"].length).to eq(31)
    # unpaid days deducted pro-rata: 2000 * (21-2)/21
    expect(emp["estimated_gross"]).to be_within(0.01).of(1809.524)
  end

  it "counts working days from the company's operating days" do
    # Gym open Mon–Sat, closed Sunday. Aug 2026 has 5 Sundays → 26 working days.
    company.update!(working_days: [ 1, 2, 3, 4, 5, 6 ])
    # A paid leave on Sat Aug 29 now lands on a working day.
    create(:leave_request, company: company, staff_member: staff, absence_type: cp, status: :approved,
           starts_on: Date.new(2026, 8, 29), ends_on: Date.new(2026, 8, 29))

    get "/api/v1/owner/payroll", params: { month: "2026-08" }, headers: auth_headers(owner)

    body = response.parsed_body
    expect(body["working_days"]).to eq(26)
    emp = body["employees"].first
    expect(emp["paid_absence_days"]).to eq(1)
    sat29 = emp["days"].find { |d| d["date"].to_s.end_with?("-29") }
    expect(sat29["code"]).to eq("leave_paid")
  end

  it "exports a PDF for the whole team" do
    get "/api/v1/owner/payroll/export", params: { month: "2026-08" }, headers: auth_headers(owner)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")
    expect(response.body[0, 4]).to eq("%PDF")
  end

  it "exports a PDF for one employee" do
    get "/api/v1/owner/payroll/export", params: { month: "2026-08", staff_member_id: staff.id }, headers: auth_headers(owner)
    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Disposition"]).to include(".pdf")
  end

  it "logs an audit entry for the export" do
    get "/api/v1/owner/payroll/export", params: { month: "2026-08" }, headers: auth_headers(owner)

    log = AuditLog.last
    expect(log.action).to eq("payroll.exported")
    expect(log.company_id).to eq(company.id)
  end

  it "is owner-only" do
    staff2 = create(:staff_member, company: company, role: :receptionist)
    get "/api/v1/owner/payroll", params: { month: "2026-08" }, headers: auth_headers(staff2.user)
    expect(response).to have_http_status(:forbidden)
  end
end
