require "rails_helper"

RSpec.describe "Api::V1::LeaveRequests", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }
  let(:staff_member) { create(:staff_member, company: company) }
  let(:absence_type) { create(:absence_type, company: company, paid: true) }

  describe "GET /api/v1/leave_requests" do
    it "lists the company's leave requests" do
      create(:leave_request, company: company, staff_member: staff_member, absence_type: absence_type)

      get "/api/v1/leave_requests", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["leave_requests"].size).to eq(1)
    end

    it "filters by staff_member_id" do
      other_staff = create(:staff_member, company: company)
      leave = create(:leave_request, company: company, staff_member: staff_member, absence_type: absence_type)
      create(:leave_request, company: company, staff_member: other_staff, absence_type: absence_type)

      get "/api/v1/leave_requests", params: { staff_member_id: staff_member.id }, headers: auth_headers(owner)

      ids = response.parsed_body["leave_requests"].map { |l| l["id"] }
      expect(ids).to eq([ leave.id ])
    end

    it "filters by year" do
      leave_2025 = create(:leave_request, company: company, staff_member: staff_member, absence_type: absence_type,
                                           starts_on: Date.new(2025, 3, 3), ends_on: Date.new(2025, 3, 7))
      create(:leave_request, company: company, staff_member: staff_member, absence_type: absence_type,
                              starts_on: Date.new(2024, 3, 3), ends_on: Date.new(2024, 3, 7))

      get "/api/v1/leave_requests", params: { year: 2025 }, headers: auth_headers(owner)

      ids = response.parsed_body["leave_requests"].map { |l| l["id"] }
      expect(ids).to eq([ leave_2025.id ])
    end

    it "never exposes another company's leave requests" do
      create(:leave_request, company: company, staff_member: staff_member, absence_type: absence_type)
      other_leave = create(:leave_request)

      get "/api/v1/leave_requests", headers: auth_headers(owner)

      ids = response.parsed_body["leave_requests"].map { |l| l["id"] }
      expect(ids).not_to include(other_leave.id)
    end

    it "forbids a receptionist from browsing leave requests" do
      receptionist = create(:staff_member, company: company, role: :receptionist)

      get "/api/v1/leave_requests", headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/leave_requests" do
    it "lets the owner record a leave request" do
      post "/api/v1/leave_requests", params: {
        leave_request: {
          staff_member_id: staff_member.id, absence_type_id: absence_type.id,
          starts_on: "2025-03-03", ends_on: "2025-03-07"
        }
      }, headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["leave_request"]["staff_member_id"]).to eq(staff_member.id)
    end

    it "rejects an end date before the start date" do
      post "/api/v1/leave_requests", params: {
        leave_request: {
          staff_member_id: staff_member.id, absence_type_id: absence_type.id,
          starts_on: "2025-03-07", ends_on: "2025-03-03"
        }
      }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns not found when the staff member belongs to another company" do
      other_staff = create(:staff_member)

      post "/api/v1/leave_requests", params: {
        leave_request: {
          staff_member_id: other_staff.id, absence_type_id: absence_type.id,
          starts_on: "2025-03-03", ends_on: "2025-03-07"
        }
      }, headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
    end

    it "forbids a coach from recording a leave request" do
      coach_staff = create(:staff_member, company: company, role: :coach)

      post "/api/v1/leave_requests", params: {
        leave_request: { staff_member_id: staff_member.id, absence_type_id: absence_type.id, starts_on: "2025-03-03", ends_on: "2025-03-07" }
      }, headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/leave_requests/:id" do
    it "lets the owner update a leave request" do
      leave = create(:leave_request, company: company, staff_member: staff_member, absence_type: absence_type, status: :pending)

      patch "/api/v1/leave_requests/#{leave.id}", params: { leave_request: { status: "approved" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(leave.reload.status).to eq("approved")
    end

    it "returns not found for another company's leave request" do
      other_leave = create(:leave_request)

      patch "/api/v1/leave_requests/#{other_leave.id}", params: { leave_request: { status: "approved" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/leave_requests/:id" do
    it "lets the owner delete a leave request" do
      leave = create(:leave_request, company: company, staff_member: staff_member, absence_type: absence_type)

      delete "/api/v1/leave_requests/#{leave.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:no_content)
      expect(LeaveRequest.exists?(leave.id)).to be false
    end

    it "never lets an owner delete another company's leave request" do
      other_leave = create(:leave_request)

      delete "/api/v1/leave_requests/#{other_leave.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
      expect(LeaveRequest.exists?(other_leave.id)).to be true
    end
  end
end
