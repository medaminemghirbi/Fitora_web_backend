require "rails_helper"

RSpec.describe "Api::V1::Me::Bookings", type: :request do
  let(:company) { create(:company) }
  let(:client) { create(:client, company: company) }
  let(:activity) { create(:activity, location: company.location) }

  describe "authorization" do
    it "forbids a staff login" do
      staff = create(:staff_member, company: company)

      get "/api/v1/me/bookings", headers: auth_headers(staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/me/bookings" do
    it "lists only this client's own upcoming bookings" do
      own_session = create(:session, activity: activity, starts_at: 2.days.from_now)
      create(:booking, client: client, session: own_session, status: :confirmed)
      other_client = create(:client, company: company)
      other_session = create(:session, activity: activity, starts_at: 3.days.from_now)
      create(:booking, client: other_client, session: other_session, status: :confirmed)

      get "/api/v1/me/bookings", headers: auth_headers(client)

      ids = response.parsed_body["bookings"].map { |b| b["id"] }
      expect(ids).to eq([ Booking.find_by(client: client).id ])
    end

    it "filters past bookings separately" do
      past_session = create(:session, activity: activity, starts_at: 2.days.ago, ends_at: 2.days.ago + 1.hour)
      create(:booking, client: client, session: past_session, status: :confirmed)

      get "/api/v1/me/bookings", params: { when: "past" }, headers: auth_headers(client)

      expect(response.parsed_body["bookings"].size).to eq(1)

      get "/api/v1/me/bookings", headers: auth_headers(client)
      expect(response.parsed_body["bookings"]).to be_empty
    end
  end

  describe "POST /api/v1/me/bookings" do
    it "books the client into a session covered by their contract" do
      session = create(:session, activity: activity, starts_at: 2.days.from_now)
      plan = create(:contract_type, company: company, unlimited_bookings: true)
      create(:contract, client: client, contract_type: plan)

      post "/api/v1/me/bookings", params: { session_id: session.id }, headers: auth_headers(client)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["booking"]["status"]).to eq("confirmed")
    end

    it "refuses a booking when the client has no covering contract" do
      session = create(:session, activity: activity, starts_at: 2.days.from_now)

      post "/api/v1/me/bookings", params: { session_id: session.id }, headers: auth_headers(client)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "refuses a session belonging to another company" do
      other_session = create(:session)

      post "/api/v1/me/bookings", params: { session_id: other_session.id }, headers: auth_headers(client)

      expect(response).to have_http_status(:not_found)
    end

    it "refuses a full session" do
      session = create(:session, activity: activity, starts_at: 2.days.from_now, capacity: 1)
      create(:booking, session: session, status: :confirmed)

      post "/api/v1/me/bookings", params: { session_id: session.id }, headers: auth_headers(client)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /api/v1/me/bookings/:id/cancel" do
    it "cancels the client's own booking" do
      session = create(:session, activity: activity, starts_at: 2.days.from_now)
      booking = create(:booking, client: client, session: session, status: :confirmed)

      post "/api/v1/me/bookings/#{booking.id}/cancel", headers: auth_headers(client)

      expect(response).to have_http_status(:ok)
      expect(booking.reload).to be_cancelled
    end

    it "404s on another client's booking" do
      other_client = create(:client, company: company)
      session = create(:session, activity: activity, starts_at: 2.days.from_now)
      booking = create(:booking, client: other_client, session: session, status: :confirmed)

      post "/api/v1/me/bookings/#{booking.id}/cancel", headers: auth_headers(client)

      expect(response).to have_http_status(:not_found)
    end
  end
end
