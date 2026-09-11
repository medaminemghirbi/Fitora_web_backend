require "rails_helper"

RSpec.describe "Api::V1::Attendance", type: :request do
  let(:company) { create(:company) }
  let(:location) { create(:location, company: company) }
  let(:activity) { create(:activity, location: location) }
  let(:coach) { create(:coach, company: company) }
  let!(:coach_location) { create(:coach_location, coach: coach, location: location) }
  let(:session) { create(:session, activity: activity, location: location, coach: coach) }
  let(:other_session) { create(:session, activity: activity, location: location) }

  describe "coach scoping" do
    it "lets a coach mark attendance for their own session's booking" do
      coach_staff = create(:staff_member, company: company, role: :coach, coach: coach)
      booking = create(:booking, session: session, status: :confirmed)

      post "/api/v1/attendance", params: { booking_id: booking.id, status: "present" }, headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["attendance"]["attendance"]["status"]).to eq("present")
    end

    it "forbids a coach from marking attendance on a session that isn't theirs" do
      coach_staff = create(:staff_member, company: company, role: :coach, coach: coach)
      booking = create(:booking, session: other_session, status: :confirmed)

      post "/api/v1/attendance", params: { booking_id: booking.id, status: "present" }, headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:forbidden)
    end

    it "only returns the coach's own sessions when listing attendance" do
      coach_staff = create(:staff_member, company: company, role: :coach, coach: coach)

      get "/api/v1/attendance", params: { session_id: other_session.id }, headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "receptionist check-in access" do
    it "lets a receptionist mark attendance on any session in the company" do
      receptionist = create(:staff_member, company: company, role: :receptionist)
      booking = create(:booking, session: session, status: :confirmed)

      post "/api/v1/attendance", params: { booking_id: booking.id, status: "present" }, headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:ok)
    end
  end

  it "forbids a manager-less staff role with no bookings/sessions/checkin capability" do
    # Every current staff role has at least one relevant capability, so this
    # documents the intended deny-by-default behavior for an inactive staff member.
    inactive_receptionist = create(:staff_member, company: company, role: :receptionist, active: false)
    booking = create(:booking, session: session, status: :confirmed)

    post "/api/v1/attendance", params: { booking_id: booking.id, status: "present" }, headers: auth_headers(inactive_receptionist.user)

    expect(response).to have_http_status(:forbidden)
  end
end
