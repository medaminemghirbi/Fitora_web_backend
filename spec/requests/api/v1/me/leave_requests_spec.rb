require "rails_helper"

RSpec.describe "Api::V1::Me::LeaveRequests", type: :request do
  let(:company) { create(:company) }
  let(:coach_staff) { create(:staff_member, company: company, role: :coach) }
  let(:absence_type) { create(:absence_type, company: company, name: "Congé payé", abbreviation: "CP", paid: true) }

  describe "authorization" do
    it "forbids an owner (no staff_member of their own)" do
      owner = company.owner

      get "/api/v1/me/leave_requests", headers: auth_headers(owner)

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids a client login" do
      client = create(:client, company: company)

      get "/api/v1/me/leave_requests", headers: auth_headers(client)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/me/leave_requests" do
    it "returns only this staff member's own requests, the company's absence types, and the CP balance" do
      absence_type
      other_coach = create(:staff_member, company: company, role: :coach)
      create(:leave_request, staff_member: coach_staff, absence_type: absence_type, company: company)
      create(:leave_request, staff_member: other_coach, absence_type: absence_type, company: company)

      get "/api/v1/me/leave_requests", headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["leave_requests"].size).to eq(1)
      expect(body["absence_types"].map { |t| t["abbreviation"] }).to include("CP")
      expect(body["balance"]).to include("entitlement", "taken", "balance")
    end
  end

  describe "POST /api/v1/me/leave_requests" do
    it "creates a pending request for the signed-in coach, ignoring any client-supplied status" do
      post "/api/v1/me/leave_requests",
           params: { leave_request: { absence_type_id: absence_type.id, starts_on: 3.days.from_now.to_date, ends_on: 4.days.from_now.to_date, status: "approved" } },
           headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:created)
      body = response.parsed_body["leave_request"]
      expect(body["status"]).to eq("pending")
      expect(body["staff_member_id"]).to eq(coach_staff.id)
    end

    it "rejects a request with no dates" do
      post "/api/v1/me/leave_requests", params: { leave_request: { absence_type_id: absence_type.id } }, headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
