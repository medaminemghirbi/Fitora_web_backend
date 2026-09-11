require "rails_helper"

RSpec.describe "Api::V1::WorkContracts & LeaveRequests", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }
  let!(:staff) { create(:staff_member, company: company, role: :receptionist) }
  let!(:cdi) { create(:work_contract_type, company: company, abbreviation: "CDI", fixed_term: false) }

  describe "work contract types" do
    it "lists the company's types (owner only)" do
      get "/api/v1/work_contract_types", headers: auth_headers(owner)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["work_contract_types"].map { |t| t["abbreviation"] }).to include("CDI")
    end

    it "forbids a receptionist" do
      staff = create(:staff_member, company: company, role: :receptionist)
      get "/api/v1/work_contract_types", headers: auth_headers(staff.user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "work contracts" do
    it "creates a contract with allowances and returns the monthly gross" do
      post "/api/v1/work_contracts",
           params: { work_contract: {
             staff_member_id: staff.id, work_contract_type_id: cdi.id,
             job_title: "Réceptionniste", starts_on: "2025-06-01",
             gross_monthly_salary: "1100", weekly_hours: "40", payment_method: "bank_transfer",
             cnss_number: "123-45", paid_leave_days_per_year: "24",
             allowances: [ { label: "Prime transport", amount: "60" } ]
           } },
           headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      body = response.parsed_body["work_contract"]
      expect(body["allowances_total"]).to eq(60.0)
      expect(body["total_monthly_gross"]).to eq(1160.0)
    end

    it "creates a contract for a coach that has no app login" do
      coach = create(:coach, company: company)

      post "/api/v1/work_contracts",
           params: { work_contract: {
             coach_id: coach.id, work_contract_type_id: cdi.id,
             job_title: "Coach", starts_on: "2025-06-01", gross_monthly_salary: "1400"
           } },
           headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      body = response.parsed_body["work_contract"]
      expect(body["coach_id"]).to eq(coach.id)
      expect(body["staff_member_id"]).to be_nil
      expect(body["employee"]).to include("kind" => "coach", "full_name" => coach.full_name)
    end

    it "lists a coach's contracts via ?coach_id=" do
      coach = create(:coach, company: company)
      contract = create(:work_contract, company: company, staff_member: nil, coach: coach, work_contract_type: cdi)

      get "/api/v1/work_contracts", params: { coach_id: coach.id }, headers: auth_headers(owner)

      expect(response.parsed_body["work_contracts"].map { |c| c["id"] }).to eq([ contract.id ])
    end

    it "rejects a contract with neither a staff member nor a coach" do
      post "/api/v1/work_contracts",
           params: { work_contract: { work_contract_type_id: cdi.id, starts_on: "2025-06-01", gross_monthly_salary: "1000" } },
           headers: auth_headers(owner)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects a contract that references both a staff member and a coach" do
      coach = create(:coach, company: company)
      post "/api/v1/work_contracts",
           params: { work_contract: { staff_member_id: staff.id, coach_id: coach.id, work_contract_type_id: cdi.id, starts_on: "2025-06-01", gross_monthly_salary: "1000" } },
           headers: auth_headers(owner)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects an end date before the start date" do
      post "/api/v1/work_contracts",
           params: { work_contract: { staff_member_id: staff.id, work_contract_type_id: cdi.id, starts_on: "2025-06-01", ends_on: "2025-01-01", gross_monthly_salary: "1000" } },
           headers: auth_headers(owner)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "scopes /staff/:id to the current work contract + leave balance" do
      contract = create(:work_contract, company: company, staff_member: staff, work_contract_type: cdi, paid_leave_days_per_year: 30)
      cp = create(:absence_type, company: company, abbreviation: "CP", paid: true)
      create(:leave_request, company: company, staff_member: staff, absence_type: cp, status: :approved,
             starts_on: Date.new(Date.current.year, 3, 3), ends_on: Date.new(Date.current.year, 3, 7), days_count: 5)

      get "/api/v1/staff/#{staff.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["current_work_contract"]["id"]).to eq(contract.id)
      expect(response.parsed_body["paid_leave_balance"]).to include("entitlement" => 30.0, "taken" => 5.0, "balance" => 25.0)
    end
  end

  describe "absence types + leave requests" do
    it "lists the company's absence types" do
      create(:absence_type, company: company, name: "Congé payé", abbreviation: "CP", paid: true)
      get "/api/v1/absence_types", headers: auth_headers(owner)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["absence_types"].map { |t| t["abbreviation"] }).to include("CP")
    end

    it "auto-computes business days and defaults to approved" do
      cp = create(:absence_type, company: company, abbreviation: "CP", paid: true)

      post "/api/v1/leave_requests",
           params: { leave_request: { staff_member_id: staff.id, absence_type_id: cp.id, starts_on: "2025-06-02", ends_on: "2025-06-06" } },
           headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      body = response.parsed_body["leave_request"]
      expect(body["days_count"]).to eq(5.0) # Mon–Fri
      expect(body["status"]).to eq("approved")
      expect(body["absence_type"]["abbreviation"]).to eq("CP")
    end

    it "only counts approved paid absence types against the CP balance" do
      cp = create(:absence_type, company: company, abbreviation: "CP", paid: true)
      unpaid = create(:absence_type, company: company, abbreviation: "CSS", paid: false)
      create(:work_contract, company: company, staff_member: staff, work_contract_type: cdi, paid_leave_days_per_year: 20)
      create(:leave_request, company: company, staff_member: staff, absence_type: cp, status: :approved,
             starts_on: Date.new(Date.current.year, 2, 3), ends_on: Date.new(Date.current.year, 2, 5), days_count: 3)
      create(:leave_request, company: company, staff_member: staff, absence_type: unpaid, status: :approved,
             starts_on: Date.new(Date.current.year, 4, 1), ends_on: Date.new(Date.current.year, 4, 4), days_count: 4)

      get "/api/v1/staff/#{staff.id}", headers: auth_headers(owner)

      expect(response.parsed_body["paid_leave_balance"]).to include("taken" => 3.0, "balance" => 17.0)
    end
  end
end
